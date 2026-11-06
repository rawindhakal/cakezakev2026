class ChatConversation {
  final String id;
  final String type;
  final String? orderId;
  final int? userId;
  final int? deliveryBoyId;
  final String title;
  final String? lastMessage;
  final String? lastSenderType;
  final DateTime? lastMessageAt;
  final String? lastTime;
  final int unreadCount;

  const ChatConversation({
    required this.id,
    required this.type,
    this.orderId,
    this.userId,
    this.deliveryBoyId,
    required this.title,
    this.lastMessage,
    this.lastSenderType,
    this.lastMessageAt,
    this.lastTime,
    this.unreadCount = 0,
  });

  bool get isAdminChat => type == 'admin_customer';

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      orderId: json['order_id']?.toString(),
      userId: int.tryParse(json['user_id']?.toString() ?? ''),
      deliveryBoyId: int.tryParse(json['delivery_boy_id']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      lastMessage: json['last_message']?.toString(),
      lastSenderType: json['last_sender_type']?.toString(),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      lastTime: json['last_time']?.toString(),
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '') ?? 0,
    );
  }
}
