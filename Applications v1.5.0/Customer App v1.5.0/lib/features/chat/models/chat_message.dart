import 'dart:convert';
import 'dart:io';

enum ChatType { deliveryBoyChat, adminChat }

enum MessageStatus { sending, sent, failed }

enum AttachmentType { image, file, audio, video }

class ChatAttachment {
  final String? localPath;
  final String? remoteUrl;
  final AttachmentType type;
  final String? fileName;

  const ChatAttachment({
    this.localPath,
    this.remoteUrl,
    required this.type,
    this.fileName,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final url = json['url']?.toString();
    final name = json['file_name']?.toString();
    final raw = json['attachment_type']?.toString() ?? 'file';
    return ChatAttachment(
      remoteUrl: url,
      type: raw == 'image'
          ? AttachmentType.image
          : raw == 'audio'
          ? AttachmentType.audio
          : raw == 'video'
          ? AttachmentType.video
          : AttachmentType.file,
      fileName: name,
    );
  }

  /// Builds from the REST shape: `attachment` (storage path) + `attachment_url` (full url).
  static const imageExtensions = {'jpeg', 'png', 'jpg', 'gif', 'webp'};
  static const audioExtensions = {
    'mp3',
    'wav',
    'ogg',
    'oga',
    'm4a',
    'aac',
    'mpga',
    'amr',
    'caf',
  };
  static const videoExtensions = {
    'mp4',
    'mov',
    'webm',
    'mkv',
    'avi',
    '3gp',
    'm4v',
    'mpeg',
    'mpg',
  };

  factory ChatAttachment.fromRest({required String path, required String url}) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return ChatAttachment(
      remoteUrl: url,
      fileName: path.split('/').last,
      type: imageExtensions.contains(ext)
          ? AttachmentType.image
          : videoExtensions.contains(ext)
          ? AttachmentType.video
          : audioExtensions.contains(ext)
          ? AttachmentType.audio
          : AttachmentType.file,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': remoteUrl,
    'file_name': fileName,
    'attachment_type': type == AttachmentType.image
        ? 'image'
        : type == AttachmentType.audio
        ? 'audio'
        : type == AttachmentType.video
        ? 'video'
        : 'file',
  };

  bool get isImage => type == AttachmentType.image;
  bool get isAudio => type == AttachmentType.audio;
  bool get isVideo => type == AttachmentType.video;
  bool get hasLocal => localPath != null && File(localPath!).existsSync();
  bool get hasRemote => remoteUrl != null && remoteUrl!.isNotEmpty;
}

class ChatMessage {
  final String id;
  final int senderId;
  final String senderType;
  final String message;
  final DateTime timestamp;
  final bool isMe;
  final MessageStatus status;
  final ChatAttachment? attachment;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
    this.attachment,
  });

  /// Parses the REST shape: `attachment` (storage path), `attachment_url` (full url),
  /// `created_at` (timestamp). Falls back to the socket shape (`timestamp`, nested
  /// `attachment` object) when those fields are absent.
  /// This app always represents a customer — sender ids aren't unique across
  /// roles (e.g. admin id 1 and customer id 1 are different people that
  /// collide numerically), so `isMe` must also require the sender role to be
  /// `customer`, not just a matching id.
  static const String ownSenderType = 'customer';

  factory ChatMessage.fromJson(Map<String, dynamic> json, int myId) {
    final senderId = int.tryParse(json['sender_id']?.toString() ?? '') ?? 0;
    final senderType = json['sender_type']?.toString() ?? '';
    ChatAttachment? attachment;
    final attachmentUrl = json['attachment_url']?.toString();
    if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
      attachment = ChatAttachment.fromRest(
        path: json['attachment']?.toString() ?? attachmentUrl,
        url: attachmentUrl,
      );
    } else if (json['attachment'] is Map<String, dynamic>) {
      attachment = ChatAttachment.fromJson(
        json['attachment'] as Map<String, dynamic>,
      );
    }
    final dateRaw = json['created_at'] ?? json['timestamp'];
    return ChatMessage(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderType: senderType,
      message: json['message']?.toString() ?? '',
      timestamp: dateRaw != null
          ? _parseServerTimestamp(dateRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      isMe: senderId == myId && senderType == ownSenderType,
      attachment: attachment,
    );
  }

  static final RegExp _kTzSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// Socket/rest timestamps arrive as wall-clock strings with no timezone
  /// marker (e.g. "2026-01-15 10:30:00"), which is the server's UTC time —
  /// Dart parses that as if it were already local, so it must be
  /// reinterpreted as UTC before converting, otherwise it never shifts to
  /// device time.
  static DateTime? _parseServerTimestamp(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    if (_kTzSuffix.hasMatch(trimmed)) return parsed.toLocal();
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    ).toLocal();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'sender_type': senderType,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    if (attachment != null) 'attachment': attachment!.toJson(),
  };

  static String buildPayload({
    required int senderId,
    required String senderType,
    required String message,
    required String roomId,
    ChatAttachment? attachment,
  }) => jsonEncode({
    'type': 'message',
    'sender_id': senderId,
    'sender_type': senderType,
    'message': message,
    'room_id': roomId,
    'timestamp': DateTime.now().toIso8601String(),
    if (attachment != null) 'attachment': attachment.toJson(),
  });

  ChatMessage copyWith({MessageStatus? status, ChatAttachment? attachment}) =>
      ChatMessage(
        id: id,
        senderId: senderId,
        senderType: senderType,
        message: message,
        timestamp: timestamp,
        isMe: isMe,
        status: status ?? this.status,
        attachment: attachment ?? this.attachment,
      );
}

class ChatScreenArgs {
  final ChatType chatType;
  final String recipientName;
  final int recipientId;
  final String? orderId;

  /// Resolved via [resolveAdminConversationId]/[resolveOrderConversationId]
  /// before navigating — used to load REST message history.
  final String? conversationId;

  /// True only when this chat was opened from the Profile screen's
  /// "Chat with Support" entry — sends the device's current lat/lng with
  /// each message. Order-opened chats (support or delivery-boy) never send
  /// location.
  final bool sendLocation;

  const ChatScreenArgs({
    required this.chatType,
    required this.recipientName,
    required this.recipientId,
    this.orderId,
    this.conversationId,
    this.sendLocation = false,
  });

  String get roomId {
    if (chatType == ChatType.deliveryBoyChat && orderId != null) {
      return 'order_$orderId';
    }
    return '$recipientId';
  }
}
