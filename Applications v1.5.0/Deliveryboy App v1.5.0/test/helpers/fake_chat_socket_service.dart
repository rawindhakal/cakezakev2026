import 'dart:async';

import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/services/chat_socket_service.dart';

/// Stand-in for [ChatSocketService] that never opens a websocket.
///
/// The real service dials a ws(s) URL the moment `connect` is called, and the
/// failure path then arms a backoff [Timer] that outlives the test ("A Timer
/// is still pending"). This fake exposes the same two streams so a test can
/// drive connection-state changes and inbound messages by hand:
///
/// ```dart
/// final socket = FakeChatSocketService();
/// final cubit = ChatCubit(repository: repo, socket: socket);
/// await cubit.connect('order_1', conversationId: '7');
/// socket.emitState(SocketConnectionState.connected);
/// socket.emitMessage(message);
/// ```
class FakeChatSocketService implements ChatSocketService {
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _stateController = StreamController<SocketConnectionState>.broadcast();

  /// Arguments the cubit passed to [connect], in order.
  final List<({String roomId, String? channelId})> connectCalls = [];

  /// Payloads passed to the legacy socket send path.
  final List<({String message, String senderType, ChatAttachment? attachment})>
  sentMessages = [];

  int disconnectCount = 0;
  bool disposed = false;

  SocketConnectionState _state = SocketConnectionState.disconnected;

  @override
  Stream<ChatMessage> get messages => _messageController.stream;

  @override
  Stream<SocketConnectionState> get connectionState => _stateController.stream;

  @override
  SocketConnectionState get state => _state;

  @override
  void connect(String roomId, {String? channelId}) {
    connectCalls.add((roomId: roomId, channelId: channelId));
  }

  @override
  void sendMessage(
    String message,
    String senderType, {
    ChatAttachment? attachment,
  }) {
    sentMessages.add((
      message: message,
      senderType: senderType,
      attachment: attachment,
    ));
  }

  @override
  void disconnect() {
    disconnectCount++;
    emitState(SocketConnectionState.disconnected);
  }

  @override
  void dispose() {
    disposed = true;
    if (!_messageController.isClosed) _messageController.close();
    if (!_stateController.isClosed) _stateController.close();
  }

  /// Pushes [state] onto the connection-state stream, as the real service
  /// does from its handshake/reconnect callbacks.
  void emitState(SocketConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  /// Pushes an inbound realtime [message] onto the message stream.
  void emitMessage(ChatMessage message) {
    if (!_messageController.isClosed) _messageController.add(message);
  }
}
