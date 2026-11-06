/// Notification `type` sent by the backend (FCM data payload and the
/// notification-list API both use the same values).
enum NotificationType {
  defaultType,
  user,
  category,
  product,
  order,
  returnRequest,
  cart,
  url,
  wallet,
  chat,
  unknown;

  static NotificationType fromRaw(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'default':
        return NotificationType.defaultType;
      case 'user':
        return NotificationType.user;
      case 'category':
        return NotificationType.category;
      case 'product':
        return NotificationType.product;
      case 'order':
        return NotificationType.order;
      case 'return_request':
        return NotificationType.returnRequest;
      case 'cart':
        return NotificationType.cart;
      case 'url':
        return NotificationType.url;
      case 'wallet':
        return NotificationType.wallet;
      case 'chat':
        return NotificationType.chat;
      default:
        return NotificationType.unknown;
    }
  }
}
