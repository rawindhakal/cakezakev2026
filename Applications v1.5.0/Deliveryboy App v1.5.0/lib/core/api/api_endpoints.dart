/// Central registry of backend API endpoint paths used across the app.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = "login";
  static const String register = "register";
  static const String forgotPassword = "forgot_password";
  static const String editProfile = "edit";
  static const String update = "update";
  static const String addFcmToken = "add_fcm_token";
  static const String updateFcmToken = "update_fcm_token";
  static const String logout = "logout";
  static const String countries = "countries";
  static const String resetPassword = "reset_password";

  static const String android = 'android';
  static const String ios = 'ios';

  static const String dashboard = "dashboard";
  static const String getDeliveryBoyStatus = "get_delivery_boy_status";
  static const String updateDeliveryBoyStatus = "update_delivery_boy_status";
  static const String cashCollection = "cash_collection";
  static const String settlementHistory = "settlement_history";
  static const String salary = "salary_transactions";
  static const String settings = "settings";
  static const String countrySettings = "country_setting";
  static const String systemLanguages = "system_languages";
  static const String zones = "zones";

  // Order Requests
  static const String orders = "orders";
  static const String orderById = "order_by_id";
  static const String updateStatus = "update_status";
  static const String updateItemStatus = "update_item_status";
  static const String orderStatuses = "order_statuses";
  static const String ecomOrders = "ecom_orders";
  static const String scanDeliveryReceipt = "scan_delivery_receipt";

  // Mail Settings
  static const String notificationPreferences = "notification_preferences";
  // static const String notificationPreferencesSave = "notification_preferences/save";

  // Delete Account
  static const String deleteDeliveryBoyAccount = "delete_account";

  // Withdrawal Requests
  static const String addWithdrawalRequest = "withdrawal_requests/add";
  static const String getWithdrawalRequests = "withdrawal_requests";

  // Return Order Requests
  static const String returnRequests = "return_requests";
  static const String returnRequestStatusUpdate =
      "return_request_status_update";

  // Live Tracking
  static const String manageLiveTracking = "manage_live_tracking";

  // Chat
  static const String chat = "chat";
  static const String chatStartAdmin = "$chat/start_admin";
  static const String chatStartOrder = "$chat/start_order";
  static const String chatMessages = "$chat/messages";
  static const String sendChatMessage = "$chat/send";
  static const String broadcastingAuth = "broadcasting/auth";

  // OSRM public demo routing server — free, no API key. Used to snap the
  // delivery-boy-to-destination tracking line onto actual roads for both
  // the Google Map and OSM (flutter_map) tracking views.
  static const String osrmRouteBaseUrl = "https://router.project-osrm.org/route/v1/driving/";
}
