import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/chat/cubit/chat_conversations_cubit.dart';

/// Resolves the admin-customer conversation id, reusing the one cached for
/// this session instead of calling chat/start_admin again.
Future<String?> resolveAdminConversationId() async {
  final cached = AuthHiveBox.instance.adminConversationId;
  if (cached != null && cached.isNotEmpty) return cached;

  final cubit = ChatConversationsCubit();
  try {
    final conversation = await cubit.startAdminConversation();
    final id = conversation?.id;
    if (id != null && id.isNotEmpty) {
      await AuthHiveBox.instance.setAdminConversationId(id);
    }
    return id;
  } finally {
    cubit.close();
  }
}

/// Resolves the customer-delivery boy conversation id for [orderId] (and
/// [orderItemId] for ecommerce orders, which key a separate thread per item),
/// reusing the one cached for this order/item instead of calling
/// chat/start_order_delivery_boy again.
Future<String?> resolveOrderConversationId(
  String orderId, {
  String? orderItemId,
}) async {
  final cacheKey = orderItemId != null && orderItemId.isNotEmpty
      ? '${orderId}_$orderItemId'
      : orderId;
  final cached = AuthHiveBox.instance.getOrderConversationId(cacheKey);
  if (cached != null && cached.isNotEmpty) return cached;

  final cubit = ChatConversationsCubit();
  try {
    final conversation = await cubit.startOrderConversation(
      orderId: orderId,
      orderItemId: orderItemId,
    );
    final id = conversation?.id;
    if (id != null && id.isNotEmpty) {
      await AuthHiveBox.instance.setOrderConversationId(cacheKey, id);
    }
    return id;
  } finally {
    cubit.close();
  }
}

/// Resolves the customer-admin conversation id scoped to [orderId], reusing
/// the one cached for this order instead of calling chat/start_order_admin again.
Future<String?> resolveOrderAdminConversationId(String orderId) async {
  final cached = AuthHiveBox.instance.getOrderAdminConversationId(orderId);
  if (cached != null && cached.isNotEmpty) return cached;

  final cubit = ChatConversationsCubit();
  try {
    final conversation = await cubit.startOrderAdminConversation(
      orderId: orderId,
    );
    final id = conversation?.id;
    if (id != null && id.isNotEmpty) {
      await AuthHiveBox.instance.setOrderAdminConversationId(orderId, id);
    }
    return id;
  } finally {
    cubit.close();
  }
}
