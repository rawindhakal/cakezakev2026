import 'dart:async';
import 'dart:convert';
import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/services/socket_url_resolver.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';

enum SocketConnectionState { disconnected, connecting, connected, reconnecting }

class ChatSocketService {
  final ChatRepository _repository;

  ChatSocketService({ChatRepository? repository})
    : _repository = repository ?? ChatRepository();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _stateController = StreamController<SocketConnectionState>.broadcast();

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<SocketConnectionState> get connectionState => _stateController.stream;

  SocketConnectionState _state = SocketConnectionState.disconnected;
  SocketConnectionState get state => _state;

  String? _roomId;
  int? _myId;

  // Set when the settings API reports a real Pusher/Reverb driver — in that
  // mode the connection speaks the actual Pusher pub/sub protocol (connect,
  // wait for pusher:connection_established, authorize + subscribe to a
  // private channel via broadcasting/auth) instead of the legacy self-hosted
  // server's raw room-in-URL scheme.
  bool _useRealProtocol = false;
  String? _channelName;
  String? _socketId;

  // Backend channel authorization is keyed by the numeric conversation id,
  // not the client-side roomId string (admin_user_4 / order_123) used for
  // the legacy URL scheme — falls back to roomId if no conversation exists
  // yet (chat not started).
  String? _channelId;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Real-protocol only: guards against the server never sending back
  // pusher_internal:subscription_succeeded (or an error frame) after we send
  // pusher:subscribe — without this, a silently-dropped ack left the state
  // stuck at `connecting` forever, with nothing logged and no retry.
  Timer? _subscribeTimeoutTimer;
  static const Duration _subscribeTimeout = Duration(seconds: 10);

  void connect(String roomId, {String? channelId}) {
    _roomId = roomId;
    _channelId = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : roomId;
    _myId = AuthHiveBox.instance.userId;
    _socketId = null;
    // Fresh retry budget for every explicit connect. [disconnect] deliberately
    // burns the budget to stop the auto-reconnect chain, so without this reset
    // a connect() after any disconnect() — e.g. ChatCubit.reconnect() on app
    // resume — gets exactly one attempt, and if that attempt fails (resuming
    // on a still-flaky network is the common case) _scheduleReconnect() bails
    // immediately and realtime chat stays dead for the rest of the screen's
    // life. Only the automatic retry path calls _connect() directly, so the
    // backoff chain itself still counts up normally.
    _reconnectAttempts = 0;
    _connect();
  }

  /// Resolves the ws(s) base URL from the settings API (see
  /// [SocketUrlResolver]) plus whether that's a real Pusher-protocol driver —
  /// falls back to the static legacy default when the driver is
  /// missing/unrecognised or the config has no key.
  ({String baseUrl, bool isRealProtocol}) _resolveSocket() {
    final baseUrl = SocketUrlResolver.resolve().baseUrl;
    if (baseUrl == null) {
      return (baseUrl: AppConfig.socketBaseUrl, isRealProtocol: false);
    }
    return (baseUrl: baseUrl, isRealProtocol: true);
  }

  void _connect() {
    // Tear down whatever the previous attempt left behind before opening a new
    // socket. The retry path reaches here straight from `catchError`/`_onDone`
    // without closing the old channel, and that channel's listener stays live —
    // its later onDone/onError would fire _scheduleReconnect() and shove the
    // state back to `disconnected` underneath the connection that replaced it.
    // Both calls are no-ops on a first connect or an already-closed channel.
    _subscribeTimeoutTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;

    final resolved = _resolveSocket();
    _useRealProtocol = resolved.isRealProtocol;
    _channelName = _useRealProtocol
        ? 'private-chat.conversation.$_channelId'
        : null;

    final uri = _useRealProtocol
        ? SocketUrlResolver.handshakeUri(resolved.baseUrl)
        : Uri.parse(
            '${resolved.baseUrl}/$_roomId?token=${AuthHiveBox.instance.getToken() ?? ''}',
          );

    _setState(SocketConnectionState.connecting);

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _subscription = channel.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Don't flip to `connected` until the handshake actually succeeds —
      // marking it optimistically right after connect() let sendMessage()
      // pass its state check and call sink.add() on a channel that had
      // already failed/closed, throwing WebSocketConnectionClosed.
      channel.ready
          .then((_) {
            if (_channel != channel) return; // superseded by a newer connect
            _reconnectAttempts = 0;
            // Real protocol: stay "connecting" until the private channel
            // subscription is confirmed by pusher_internal:subscription_succeeded
            // (see _handleProtocolFrame) — legacy server has no such ack.
            if (!_useRealProtocol) _setState(SocketConnectionState.connected);
          })
          .catchError((_) {
            if (_channel != channel) return;
            _setState(SocketConnectionState.disconnected);
            _scheduleReconnect();
          });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final Map<String, dynamic> json = jsonDecode(raw as String);
      final event = json['event']?.toString();

      if (event != null) {
        _handleProtocolFrame(event, json);
        return;
      }

      // Legacy self-hosted server — raw custom JSON, no `event` envelope.
      final type = json['type']?.toString();
      if (type == 'message' || type == null) {
        final msg = ChatMessage.fromJson(json, _myId ?? 0);
        _messageController.add(msg);
      }
    } catch (_) {}
  }

  /// Pusher/Reverb protocol frames — connection + subscription lifecycle,
  /// plus the actual chat broadcasts once subscribed.
  void _handleProtocolFrame(String event, Map<String, dynamic> json) {
    switch (event) {
      case 'pusher:connection_established':
        final payload = json['data'];
        final data = payload is String ? jsonDecode(payload) : payload;
        _socketId = (data as Map?)?['socket_id']?.toString();
        _subscribeChannel();
      case 'pusher:ping':
        _channel?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
      case 'pusher_internal:subscription_succeeded':
        if (json['channel'] == _channelName) {
          _subscribeTimeoutTimer?.cancel();
          _setState(SocketConnectionState.connected);
        }
      case 'pusher:error':
      case 'pusher_internal:subscription_error':
        // The server explicitly told us the subscription failed — without
        // this fallback the state stayed stuck at `connecting` forever since
        // nothing else moves it off that value.
        logDebug('ChatSocketService: $event ${json['data']}');
        _subscribeTimeoutTimer?.cancel();
        _setState(SocketConnectionState.disconnected);
        _scheduleReconnect();
      default:
        if (_channelName != null && json['channel'] == _channelName) {
          final payload = json['data'];
          final data = payload is String ? jsonDecode(payload) : payload;
          logDebug('ChatSocketService: message event=$event data=$data');
          if (data is Map<String, dynamic>) {
            _messageController.add(ChatMessage.fromJson(data, _myId ?? 0));
          }
        } else {
          logDebug(
            'ChatSocketService: ignored event=$event channel=${json['channel']} (subscribed to $_channelName)',
          );
        }
    }
  }

  /// Authorizes and subscribes to this room's private channel — called once
  /// the socket_id is known from pusher:connection_established.
  Future<void> _subscribeChannel() async {
    final socketId = _socketId;
    final channelName = _channelName;
    if (socketId == null || channelName == null) return;
    try {
      final auth = await _repository.getBroadcastAuth(
        socketId: socketId,
        channelName: channelName,
      );
      final authSignature = auth['auth']?.toString();
      if (authSignature == null) {
        // Malformed auth response — same as a failed call below, don't
        // leave the state stuck at `connecting` forever.
        _setState(SocketConnectionState.disconnected);
        _scheduleReconnect();
        return;
      }
      _channel?.sink.add(
        jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': channelName, 'auth': authSignature},
        }),
      );
      // The frame is sent, but the server may never ack it — fall back to a
      // reconnect if pusher_internal:subscription_succeeded/error doesn't
      // arrive within the timeout, instead of hanging at `connecting` forever.
      _subscribeTimeoutTimer?.cancel();
      _subscribeTimeoutTimer = Timer(_subscribeTimeout, () {
        if (_state == SocketConnectionState.connected) return;
        logDebug(
          'ChatSocketService: subscription ack timed out for $channelName',
        );
        _setState(SocketConnectionState.disconnected);
        _scheduleReconnect();
      });
    } catch (e) {
      // Auth call failed/timed out — without this, state stays stuck at
      // `connecting` forever (no other path moves it), which left the chat
      // screen showing its loading skeleton indefinitely even though REST
      // history had already loaded. Falling back to disconnected lets the
      // cubit show that history plus the reconnect banner, and retries the
      // socket via the normal backoff.
      logDebug('ChatSocketService: broadcasting/auth failed — $e');
      _setState(SocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _onError(Object error) {
    _setState(SocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _onDone() {
    _setState(SocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    _setState(SocketConnectionState.reconnecting);
    _reconnectTimer = Timer(delay, _connect);
  }

  /// Legacy self-hosted server only — real Pusher/Reverb channels don't
  /// accept arbitrary client-sent events without the `client-` event prefix
  /// and client events explicitly enabled server-side; outgoing chat
  /// messages go through the REST send API (see ChatCubit.sendMessage)
  /// regardless of driver.
  void sendMessage(
    String message,
    String senderType, {
    ChatAttachment? attachment,
  }) {
    if (_useRealProtocol) return;
    if (_channel == null || _state != SocketConnectionState.connected) return;
    final payload = ChatMessage.buildPayload(
      senderId: _myId ?? 0,
      senderType: senderType,
      message: message,
      roomId: _roomId ?? '',
      attachment: attachment,
    );
    try {
      _channel!.sink.add(payload);
    } catch (_) {
      // Connection died between the state check and send — onError/onDone
      // will handle reconnecting; nothing more to do here.
    }
  }

  void _setState(SocketConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscribeTimeoutTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    _subscription?.cancel();
    _channel?.sink.close();
    _socketId = null;
    _setState(SocketConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
