import 'dart:async';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_socket_service.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatConnecting extends ChatState {}

class ChatConnected extends ChatState {
  final List<ChatMessage> messages;
  ChatConnected(this.messages);
}

class ChatReconnecting extends ChatState {
  final List<ChatMessage> messages;
  ChatReconnecting(this.messages);
}

class ChatDisconnected extends ChatState {
  final List<ChatMessage> messages;
  ChatDisconnected(this.messages);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Manages a single chat room: loads REST history, connects the realtime
/// socket, and sends/receives messages with optimistic UI updates.
class ChatCubit extends Cubit<ChatState> {
  late final ChatSocketService _socket;
  final ChatRepository _repository;
  final List<ChatMessage> _messages = [];
  StreamSubscription? _msgSub;
  StreamSubscription? _stateSub;

  late final int _myId;
  // This app's own surface name — it was 'customer', carried over from the
  // customer app. Nothing reads it on the current send path (outgoing messages
  // go over REST, and bubble sides come from `senderId == myId`, not this), so
  // the wrong value stayed invisible; it would only surface if the legacy
  // socket send path (ChatMessage.buildPayload) is ever switched back on.
  // Matches the 'delivery_boy' surface name used by MaintenanceSocketService.
  static const String _senderType = 'delivery_boy';
  String? _conversationId;

  /// The `ChatCubit` backing whichever chat screen is currently open, if
  /// any — at most one is on-screen at a time. Lets `NotificationService`
  /// know whether an incoming chat push is for a conversation the user is
  /// already looking at, so it can suppress the popup (and locally refresh
  /// instead, if the socket is down) rather than show a redundant
  /// notification for a chat already visible.
  static ChatCubit? active;

  String? get conversationId => _conversationId;
  bool get isSocketConnected => _socket.state == SocketConnectionState.connected;

  /// Test seam: when set, [ChatCubit] builds its realtime transport from
  /// this instead of opening a real websocket. Screens construct their own
  /// `ChatCubit()`, so a constructor argument alone can't reach them.
  @visibleForTesting
  static ChatSocketService Function(ChatRepository repository)? socketFactory;

  ChatCubit({ChatRepository? repository, ChatSocketService? socket})
    : _repository = repository ?? ChatRepository(),
      super(ChatInitial()) {
    _myId = int.tryParse(AuthHiveBox.instance.userId) ?? 0;
    _socket =
        socket ??
        socketFactory?.call(_repository) ??
        ChatSocketService(repository: _repository);
  }

  /// Loads REST message history for [conversationId] (if any) before
  /// connecting the socket, so past messages show immediately instead of
  /// only ones sent during this live session.
  Future<void> connect(String roomId, {String? conversationId}) async {
    emit(ChatConnecting());
    _conversationId = conversationId;
    active = this;

    if (conversationId != null && conversationId.isNotEmpty) {
      try {
        final history = await _repository.getMessages(
          conversationId: conversationId,
          myId: _myId,
        );
        _messages.addAll(history);
      } on ApiException {
        // History is a nice-to-have — keep connecting even if it fails.
      } catch (e) {
        logDebug(() => 'ChatCubit.connect history load failed: $e');
      }
    }

    _stateSub = _socket.connectionState.listen((s) {
      switch (s) {
        case SocketConnectionState.connected:
          emit(ChatConnected(List.unmodifiable(_messages)));
        case SocketConnectionState.reconnecting:
          emit(ChatReconnecting(List.unmodifiable(_messages)));
        case SocketConnectionState.disconnected:
          emit(ChatDisconnected(List.unmodifiable(_messages)));
        case SocketConnectionState.connecting:
          // Only show the full skeleton for the very first connect — every
          // auto-reconnect retry passes through `connecting` again, and
          // once there's content on screen that used to wipe it back to a
          // bare skeleton loader on every attempt. With messages already
          // loaded, keep them visible with the reconnecting banner instead.
          if (_messages.isEmpty) {
            emit(ChatConnecting());
          } else {
            emit(ChatReconnecting(List.unmodifiable(_messages)));
          }
      }
    });

    _msgSub = _socket.messages.listen((msg) {
      // The server broadcasts a sender's own message back to every
      // subscriber of the channel, including the sender — merge by id
      // instead of always appending, or a message we just sent via REST
      // shows a second time once its real-time echo arrives.
      final existingIdx = _messages.indexWhere((m) => m.id == msg.id);
      if (existingIdx != -1) {
        _messages[existingIdx] = msg;
      } else {
        _messages.add(msg);
      }
      if (state is ChatConnected) {
        emit(ChatConnected(List.unmodifiable(_messages)));
      } else if (state is ChatReconnecting) {
        emit(ChatReconnecting(List.unmodifiable(_messages)));
      }
    });

    _socket.connect(roomId, channelId: conversationId);
  }

  /// Sends [text] (and/or [attachment]) optimistically, then reconciles with
  /// the server response or marks the message failed on error.
  Future<void> sendMessage(String text, {ChatAttachment? attachment}) async {
    if (text.trim().isEmpty && attachment == null) return;
    final conversationId = _conversationId;

    final optimistic = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myId,
      senderType: _senderType,
      message: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sending,
      attachment: attachment,
    );

    _messages.add(optimistic);
    emit(ChatConnected(List.unmodifiable(_messages)));

    if (conversationId == null || conversationId.isEmpty) {
      _markFailed(optimistic.id);
      return;
    }

    try {
      final attachmentPath = attachment?.localPath;
      final attachmentType = attachment?.type;
      final sent = await _repository.sendMessage(
        conversationId: conversationId,
        message: text.trim(),
        myId: _myId,
        imagePaths:
            attachmentPath != null && attachmentType == AttachmentType.image
            ? [attachmentPath]
            : null,
        audioPaths:
            attachmentPath != null && attachmentType == AttachmentType.audio
            ? [attachmentPath]
            : null,
        videoPaths:
            attachmentPath != null && attachmentType == AttachmentType.video
            ? [attachmentPath]
            : null,
        filePaths:
            attachmentPath != null && attachmentType == AttachmentType.file
            ? [attachmentPath]
            : null,
      );
      final idx = _messages.indexWhere((m) => m.id == optimistic.id);
      if (idx != -1) {
        final finalMsg = sent.isNotEmpty
            ? sent.first.copyWith(status: MessageStatus.sent)
            : optimistic.copyWith(status: MessageStatus.sent);
        // The real-time echo of this same message can arrive before this
        // REST response does and get appended under its real id already —
        // drop the stale optimistic slot and any such duplicate so only one
        // entry for this message remains.
        _messages.removeWhere(
          (m) => m.id == optimistic.id || m.id == finalMsg.id,
        );
        _messages.add(finalMsg);
        if (!isClosed) emit(ChatConnected(List.unmodifiable(_messages)));
      }
    } catch (_) {
      _markFailed(optimistic.id);
    }
  }

  /// Loads the next page of older history and prepends it. Used by pull-to-refresh.
  Future<void> loadOlderMessages() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    try {
      final older = await _repository.getMessages(
        conversationId: conversationId,
        myId: _myId,
        offset: _messages.length,
      );
      if (older.isEmpty) return;
      _messages.insertAll(0, older);
      final current = state;
      if (current is ChatConnected) {
        emit(ChatConnected(List.unmodifiable(_messages)));
      } else if (current is ChatReconnecting) {
        emit(ChatReconnecting(List.unmodifiable(_messages)));
      } else if (current is ChatDisconnected) {
        emit(ChatDisconnected(List.unmodifiable(_messages)));
      }
    } on ApiException {
      // Best-effort — keep current state on failure.
    } catch (e) {
      logDebug(() => 'ChatCubit.loadOlderMessages failed: $e');
    }
  }

  /// Called by `NotificationService` when a chat push arrives for this
  /// exact conversation while the socket is disconnected — the live socket
  /// won't deliver the new message, so pull it via REST instead to reflect
  /// it on screen without showing a redundant popup notification.
  Future<void> refreshFromNotification() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    try {
      final latest = await _repository.getMessages(
        conversationId: conversationId,
        myId: _myId,
      );
      var changed = false;
      for (final msg in latest) {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx == -1) {
          _messages.add(msg);
          changed = true;
        } else {
          _messages[idx] = msg;
        }
      }
      if (!changed) return;
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (!isClosed) emit(ChatConnected(List.unmodifiable(_messages)));
    } on ApiException {
      // Best-effort — next socket reconnect or manual refresh catches up.
    } catch (e) {
      logDebug(() => 'ChatCubit.refreshFromNotification failed: $e');
    }
  }

  void _markFailed(String id) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
      if (!isClosed) emit(ChatConnected(List.unmodifiable(_messages)));
    }
  }

  /// Disconnects and reconnects the socket for [roomId] (e.g. after an app resume).
  void reconnect(String roomId) {
    _socket.disconnect();
    _socket.connect(roomId, channelId: _conversationId);
  }

  Future<void> downloadAttachment(String url, String savePath) {
    return _repository.downloadAttachment(url, savePath);
  }

  @override
  Future<void> close() {
    if (identical(active, this)) active = null;
    _msgSub?.cancel();
    _stateSub?.cancel();
    _socket.dispose();
    return super.close();
  }
}
