import 'dart:io';

abstract final class AppConstants {
  static const String quick = 'quick';
  static const String ecommerce = 'ecommerce';
  static const String both = 'both';
  static const String wallet = 'wallet';

  static const String android = 'android';
  static const String ios = 'ios';

  static String platformType = Platform.isAndroid ? android : ios;

  static String percentSymbol = '%';
  static String celebrateSymbol = '🎉';
  static String hashSymbol = '#';

  static const int defaultDecimalPoint = 2;

  // home builder — sections page size for infinite-scroll pagination
  static const int homeSectionsPageLimit = 10;

  //map Provider
  static String mapProvider = 'google';
  static const List<String> osmTileSubdomains = ['a', 'b', 'c', 'd'];

  //payment getaway type
  static const phonepe = 'Phonepe';
  static const midtrans = 'Midtrans';
  static const paystack = 'Paystack';
  static const stripe = 'Stripe';
  static const paypal = 'Paypal';
  static const razorpay = 'Razorpay';
  static const cashfree = 'Cashfree';
  static const paytabs = 'Paytabs';
  static const cod = 'COD';
  static const dpo = 'DPO';
  // Backend matches case-insensitively but documents lowercase for PayU.
  static const payu = 'payu';

  // analytics event names
  static const String eventLogin = 'login';
  static const String eventSignUp = 'sign_up';
  static const String eventSearch = 'search';
  static const String eventAddToCart = 'add_to_cart';
  static const String eventRemoveFromCart = 'remove_from_cart';
  static const String eventPurchase = 'purchase';
  static const String eventProfileUpdate = 'profile_update';
  static const String eventWalletTopup = 'wallet_topup';
  static const String eventToggleFavorite = 'toggle_favorite';
  static const String clarityEventFavoriteAdded = 'favorite_added';
  static const String clarityEventFavoriteRemoved = 'favorite_removed';

  // login method values (for eventLogin's paramMethod param)
  static const String loginMethodPhoneOtp = 'phone_otp';
  static const String loginMethodPhonePassword = 'phone_password';
  static const String loginMethodEmailPassword = 'email_password';
  static const String loginMethodGoogle = 'google';
  static const String loginMethodApple = 'apple';

  // analytics event parameter keys
  static const String paramMethod = 'method';
  static const String paramUserId = 'user_id';
  static const String paramSearchTerm = 'search_term';
  static const String paramItemId = 'item_id';
  static const String paramQuantity = 'quantity';
  static const String paramTransactionId = 'transaction_id';
  static const String paramValue = 'value';
  static const String paramPaymentType = 'payment_type';
  static const String paramAmount = 'amount';
  static const String paramCurrency = 'currency';
  static const String paramProductId = 'product_id';
  static const String paramIsFavorite = 'is_favorite';

  // deep link / share url segments
  static const String deepLinkProductSegment = 'product';
  static const String deepLinkIsMobileParam = 'isMobile';
}
