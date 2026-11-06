import 'dart:io';

/// App-wide string literals: order type flags and analytics event/parameter names.
abstract final class AppConstants {
  static const String quick = 'quick';
  static const String ecommerce = 'ecommerce';

  static const String mapProviderGoogle = 'google';
  static const List<String> mapTileSubdomains = ['a', 'b', 'c', 'd'];

  static const String android = 'android';
  static const String ios = 'ios';

  static String heySymbol = '👋';
  static String crossQtySymbol = '×';
  static String hashSymbol = '#';

  static String platformType = Platform.isAndroid ? android : ios;

  // analytics event names
  static const String eventLogin = 'login';
  static const String eventSignUp = 'sign_up';
  static const String eventProfileUpdate = 'profile_update';
  static const String eventOrderStatusUpdate = 'order_status_update';
  static const String eventReturnOrderStatusUpdate =
      'return_order_status_update';
  static const String eventWithdrawalRequest = 'withdrawal_request';

  // analytics event parameter keys
  static const String paramMethod = 'method';
  static const String paramUserId = 'user_id';
  static const String paramOrderId = 'order_id';
  static const String paramOrderItemId = 'order_item_id';
  static const String paramOrderStatus = 'order_status';
  static const String paramReturnRequestId = 'return_request_id';
  static const String paramAmount = 'amount';
}
