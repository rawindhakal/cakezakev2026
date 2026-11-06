import 'dart:async';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_socket_service.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class ChatState {}

final class ChatInitial extends ChatState {}

final class ChatConnecting extends ChatState {}

final class ChatConnected extends ChatState {
  final List<ChatMessage> messages;
  // True when this emission only prepended older history (pull-to-refresh) —
  // the screen shouldn't auto-scroll to bottom for those, only for new
  // messages/sends arriving at the tail.
  final bool isOlderMessagesLoad;
  ChatConnected(this.messages, {this.isOlderMessagesLoad = false});
}

final class ChatReconnecting extends ChatState {
  final List<ChatMessage> messages;
  ChatReconnecting(this.messages);
}

final class ChatDisconnected extends ChatState {
  final List<ChatMessage> messages;
  ChatDisconnected(this.messages);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ChatCubit extends Cubit<ChatState> {
  late final ChatSocketService _socket;
  final ChatRepository _repository;
  final List<ChatMessage> _messages = [];
  StreamSubscription? _msgSub;
  StreamSubscription? _stateSub;

  late final int _myId;
  static const String _senderType = 'customer';
  String? _conversationId;
  final bool _sendLocation;

  /// The `ChatCubit` backing whichever `ChatScreen` is currently open, if
  /// any — at most one chat screen is on-screen at a time. Lets
  /// `NotificationService` know whether an incoming chat push is for a
  /// conversation the user is already looking at, so it can suppress the
  /// popup (and locally refresh instead, if the socket is down) rather than
  /// show a redundant notification for a chat already visible.
  static ChatCubit? active;

  String? get conversationId => _conversationId;
  bool get isSocketConnected =>
      _socket.state == SocketConnectionState.connected;

  ChatCubit({ChatRepository? repository, bool sendLocation = false})
    : _repository = repository ?? ChatRepository(),
      _sendLocation = sendLocation,
      super(ChatInitial()) {
    _myId = AuthHiveBox.instance.userId;
    _socket = ChatSocketService(repository: _repository);
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
      } catch (_) {}
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
        latitude: _sendLocation ? SettingsHiveBox.instance.userLatitude : null,
        longitude: _sendLocation
            ? SettingsHiveBox.instance.userLongitude
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
        emit(
          ChatConnected(
            List.unmodifiable(_messages),
            isOlderMessagesLoad: true,
          ),
        );
      } else if (current is ChatReconnecting) {
        emit(ChatReconnecting(List.unmodifiable(_messages)));
      } else if (current is ChatDisconnected) {
        emit(ChatDisconnected(List.unmodifiable(_messages)));
      }
    } on ApiException {
      // Best-effort — keep current state on failure.
    } catch (_) {}
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
    } catch (_) {}
  }

  /// Retries a message stuck in [MessageStatus.failed] — removes it and
  /// resends its content/attachment as a fresh optimistic message, since
  /// there's otherwise no way to recover it short of retyping.
  Future<void> retryMessage(String id) async {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final failed = _messages[idx];
    _messages.removeAt(idx);
    if (!isClosed) emit(ChatConnected(List.unmodifiable(_messages)));
    await sendMessage(failed.message, attachment: failed.attachment);
  }

  void _markFailed(String id) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
      if (!isClosed) emit(ChatConnected(List.unmodifiable(_messages)));
    }
  }

  void reconnect(String roomId) {
    _socket.disconnect();
    _socket.connect(roomId, channelId: _conversationId);
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
