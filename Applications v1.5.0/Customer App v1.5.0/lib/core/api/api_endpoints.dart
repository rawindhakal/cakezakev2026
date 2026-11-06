class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = "login";
  static const String sendSms = "send_sms";
  static const String verifyUser = "verify_user";
  static const String register = "register";
  static const String verifyEmail = "verify_email";
  static const String sendEmailForgotPasswordOtp =
      "send_email_forgot_password_otp";
  static const String forgotPassword = "forgot_password";
  static const String editProfile = "edit_profile";
  static const String userDetails = "user_details";
  static const String addFcmToken = "add_fcm_token";
  static const String updateFcmToken = "update_fcm_token";
  static const String logout = "logout";
  static const String verifyUserExist = "verify_user_exist";
  static const String resetPassword = "reset_password";

  static const String settings = "settings";
  static const String zone = "zone";
  static const String zones = "zones";
  static const String regions = "regions";
  static const String countries = "countries";
  static const String systemLanguages = "system_languages";

  // Order Requests
  static const String orders = "orders";
  static const String ecomOrders = "ecom_orders";
  static const String updateOrderStatus = "update_order_status";

  // Mail Settings
  static const String notificationPreferences = "notification_preferences";
  // static const String notificationPreferencesSave = "notification_preferences/save";

  //blog
  static const String blogCategories = 'blog_categories';
  static const String blogs = 'blogs';

  static const String categories = "categories";
  static const String liveTracking = "live_tracking";
  static const String brands = "brands";
  static const String products = "products";
  static const String ratingsList = "$products/ratings_list";
  static const String ratingAdd = "$products/rating/add";
  static const String ratingUpdate = "$products/rating/update";
  static const String ratingImages = "$products/rating/image_list";
  static const String appSettings = "settings";
  static const String paymentMethodsSettings = "$appSettings/payment_methods";
  static const String countrySettings = "country_setting";
  static const String favorite = "favorites";
  static const String addProductToFavorite = "favorites/add";
  static const String removeProductFromFavorite = "favorites/remove";
  static const String productDetail = "product_by_id";
  static const String checkServiceability = "check_serviceability";
  static const String faq = "faqs";
  static const String notification = "notifications";
  static const String updateProfile = "edit_profile";
  static const String cart = "cart";
  static const String guestCart = "$cart/guest_cart";
  static const String guestCartBulkAddToCartWhileLogin =
      "$cart/bulk_add_to_cart_items";
  static const String cartAdd = "$cart/add";
  static const String cartRemove = "$cart/remove";
  static const String cartRecommendations = "$cart/recommendations";
  static const String ordersHistory = "orders";

  static const String promoCode = "promo_code";
  static const String promoCodeValidate = "$promoCode/validate";
  static const String address = "address";
  static const String addressAdd = "$address/add";
  static const String addressUpdate = "$address/update";
  static const String addressRemove = "$address/delete";
  static const String placeOrder = "place_order";
  static const String initiateTransaction = "initiate_transaction";
  static const String addTransaction = "add_transaction";
  static const String deleteAccount = "delete_account";
  static const String transaction = "get_user_transactions";
  static const String downloadOrderInvoice =
      "invoice_download"; //for quick order
  static const String downloadItemInvoice =
      "item_invoice_download"; // for ecommerce order
  static const String paytmTransactionToken = "paytm_txn_token";
  static const String deleteOrder = "delete_order";
  static const String orderStatusPhonepe = "order_status_phonepe";
  static const String googlePlacesAutocomplete = 'places_autocomplete';
  static const String googlePlacesDetails = 'places_details';
  static const String googleMapsGeocoding = 'maps_geocoding';
  static const String recentlyVisited = 'products/recently_visited';
  static const String filters = '$products/filters';
  static const String addRecentlyVisitedProduct =
      'products/add_recently_visited_product';
  static const String notifyMe = '$products/notify_me';
  static const String removeNotifyMe = '$products/notify_me/remove';
  static const String homeLayout = 'home_layout';
  static const String pageBuilder = 'page_builder';

  // Chat
  static const String chat = "chat";
  static const String chatStartAdmin = "$chat/start_admin";
  static const String chatStartOrder = "$chat/start_order_delivery_boy";
  static const String chatStartOrderAdmin = "$chat/start_order_admin";
  static const String chatMessages = "$chat/messages";
  static const String sendChatMessage = "$chat/send";
  static const String broadcastingAuth = "broadcasting/auth";

  // Spin Wheel
  static const String spinWheel = "spin_wheel";
  static const String spinWheelRewards = "$spinWheel/rewards";
  static const String spinWheelSpin = "$spinWheel/spin";

  // OSRM public demo routing server — free, no API key. Used to snap the
  // delivery-boy-to-destination tracking line onto actual roads for both
  // the Google Map and OSM (flutter_map) tracking views.
  static const String osrmRouteBaseUrl =
      "https://router.project-osrm.org/route/v1/driving/";

  // Public Google Maps search deep link — no API key needed. Opens a
  // location (lat,lng or address text) in the external Maps app/browser,
  // e.g. for "get directions" to a pickup store.
  static const String googleMapsSearchBaseUrl =
      "https://www.google.com/maps/search/?api=1&query=";
}
