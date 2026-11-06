import 'dart:async';
import 'dart:convert';

import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/services/socket_url_resolver.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Listens on the public "maintenance" channel for a "maintenance.toggled"
/// event so the full-block maintenance mode (admin panel on/off switch)
/// takes effect immediately while the app is open, without waiting for the
/// next settings api poll.
///
/// Mirrors the connection-resolution rules of ChatSocketService
/// (broadcast_driver/broadcast_config from the settings api) but is
/// deliberately kept separate — this is a public channel, no auth handshake.
class MaintenanceSocketService {
  MaintenanceSocketService._();
  static final MaintenanceSocketService instance = MaintenanceSocketService._();

  static const String _channelName = 'maintenance';
  static const String _toggledEvent = 'maintenance.toggled';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _subscribed = false;

  // Pusher's `activity_timeout` (sent in pusher:connection_established) is
  // how long *we* may stay silent before we're expected to ping — if we
  // never do, the server (or an intermediary proxy) drops the connection
  // as idle. Reset on every received frame; fires our own ping otherwise.
  Timer? _activityTimer;
  Duration _activityTimeout = const Duration(seconds: 110);

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _toggledController = StreamController<AppSettingsData>.broadcast();

  /// Emits the merged settings snapshot (updated `appModeCustomer`/
  /// `appModeCustomerRemark`) whenever a full-block toggle event arrives.
  Stream<AppSettingsData> get onToggled => _toggledController.stream;

  void connect() {
    _reconnectTimer?.cancel();
    if (_channel != null) {
      logDebug(
        'MaintenanceSocketService: connect() skipped — already have a channel',
      );
      return;
    }

    final endpoint = SocketUrlResolver.resolve();
    final baseUrl = endpoint.baseUrl;
    if (baseUrl == null) {
      logDebug(
        'MaintenanceSocketService: connect() skipped — '
        '${endpoint.unavailableReason}',
      );
      return;
    }

    logDebug(
      'MaintenanceSocketService: connecting to $baseUrl '
      '(driver=${endpoint.driver})',
    );

    try {
      final channel = WebSocketChannel.connect(
        SocketUrlResolver.handshakeUri(baseUrl),
      );
      _channel = channel;
      _subscribed = false;
      _subscription = channel.stream.listen(
        _onData,
        onError: (e) {
          logDebug('MaintenanceSocketService: socket error — $e');
          disconnect();
          _scheduleReconnect();
        },
        onDone: () {
          logDebug(
            'MaintenanceSocketService: socket closed — '
            'code=${channel.closeCode} reason=${channel.closeReason}',
          );
          disconnect();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
      channel.ready
          .then((_) {
            _reconnectAttempts = 0;
          })
          .catchError((_) {});
    } catch (e) {
      logDebug('MaintenanceSocketService: connect() threw — $e');
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    logDebug(
      'MaintenanceSocketService: reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );
    _reconnectTimer = Timer(delay, connect);
  }

  void _resetActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer(_activityTimeout, () {
      // No frame (from either side) in `_activityTimeout` — ping the server
      // ourselves per the Pusher protocol, otherwise it (or a proxy in
      // between) treats the connection as idle and drops it.
      logDebug('MaintenanceSocketService: idle — sending our own ping');
      _channel?.sink.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
      _resetActivityTimer();
    });
  }

  void _onData(dynamic raw) {
    _resetActivityTimer();
    try {
      final Map<String, dynamic> json = jsonDecode(raw as String);
      final event = json['event']?.toString();
      logDebug(
        'MaintenanceSocketService: frame event=$event channel=${json['channel']} '
        'data=${json['data']}',
      );
      switch (event) {
        case 'pusher:connection_established':
          final payload = json['data'];
          final data = payload is String ? jsonDecode(payload) : payload;
          final timeoutSeconds = (data as Map?)?['activity_timeout'] as int?;
          if (timeoutSeconds != null && timeoutSeconds > 5) {
            // Ping a bit before the server's own deadline, not after it.
            _activityTimeout = Duration(seconds: timeoutSeconds - 5);
          }
          _subscribeChannel();
        case 'pusher:ping':
          _channel?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        case _ when event == _toggledEvent && json['channel'] == _channelName:
          _handleToggled(json['data']);
        default:
          break;
      }
    } catch (e) {
      logDebug('MaintenanceSocketService: failed to parse frame — $e');
    }
  }

  void _subscribeChannel() {
    if (_subscribed || _channel == null) return;
    _subscribed = true;
    logDebug('MaintenanceSocketService: subscribing to "$_channelName"');
    _channel!.sink.add(
      jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': _channelName},
      }),
    );
  }

  // This app's identifier in the broadcast payload's "surface" field — the
  // same channel/event carries toggles for every surface (customer,
  // delivery_boy, seller); events for other surfaces are ignored.
  static const String _surface = 'customer';

  /// Actual payload shape (confirmed from live testing):
  /// `{"surface":"customer","mode":1,"remark":{"en":"...","ur":""}}` — no
  /// scheduled start/end here, this is the immediate full-block toggle only.
  /// The scheduled-window popup ([MaintenanceScheduledDialog]) is driven
  /// purely by the settings api poll, not this socket.
  void _handleToggled(dynamic payload) {
    try {
      final decoded = payload is String ? jsonDecode(payload) : payload;
      if (decoded is! Map) return;
      if (decoded['surface']?.toString() != _surface) return;

      final mode = decoded['mode']?.toString() ?? '0';
      final remarkField = decoded['remark'];
      String? remark;
      if (remarkField is Map) {
        final lang = SettingsHiveBox.instance.languageCode;
        remark = remarkField[lang]?.toString();
        if (remark == null || remark.isEmpty) {
          remark = remarkField['en']?.toString();
        }
      } else {
        remark = remarkField?.toString();
      }

      final current = SettingsHiveBox.instance.getAppSettings();
      if (current == null) return;
      current.appModeCustomer = mode;
      if (remark != null) current.appModeCustomerRemark = remark;

      SettingsHiveBox.instance.saveAppSettings(current);
      logDebug('MaintenanceSocketService: toggled — mode=$mode remark=$remark');
      if (!_toggledController.isClosed) _toggledController.add(current);
    } catch (e) {
      logDebug('MaintenanceSocketService: bad payload — $e');
    }
  }

  void disconnect() {
    _activityTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscribed = false;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    disconnect();
    _toggledController.close();
  }
}
