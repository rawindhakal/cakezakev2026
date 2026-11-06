/// Central registry of request body/query parameter key names used across API calls.
class ApiParameters {
  ApiParameters._();

  // ── Common ────────────────────────────────────────────────────────────────
  static const String mobile = 'mobile';
  static const String password = 'password';
  static const String email = 'email';
  static const String name = 'name';
  static const String image = 'image';
  static const String profile = 'profile';
  static const String status = 'status';
  static const String message = 'message';
  static const String type = 'type';
  static const String bonusType = "bonus_type";
  static const String bonusPercentage = "bonus_percentage";
  static const String bonusMinAmount = "bonus_min_amount";
  static const String bonusMaxAmount = "bonus_max_amount";
  static const String returnBonusType = "return_bonus_type";
  static const String returnBonusPercentage = "return_bonus_percentage";
  static const String returnBonusMinAmount = "return_bonus_min_amount";
  static const String returnBonusMaxAmount = "return_bonus_max_amount";
  static const String statusId = "status_id";
  static const String otp = "otp";
  static const String code = "code";
  static const String entryType = "entry_type";

  static const String android = 'android';
  static const String ios = 'ios';

  // ── Auth: Login ───────────────────────────────────────────────────────────
  static const String accessToken = 'access_token';
  static const String platform = "platform";
  static const String fcmToken = 'fcm_token';
  static const String languageId = 'language_id';

  // ── Auth: Register ────────────────────────────────────────────────────────
  static const String dob = 'dob';
  static const String nationalIdentityCard = 'national_identity_card';
  static const String drivingLicense = 'driving_license';
  static const String address = 'address';
  static const String countryId = 'country_id';
  static const String countryCode = 'country_code';
  static const String zoneId = 'zone_id';

  // ── Auth: Forgot / Change Password ────────────────────────────────────────
  static const String oldPassword = 'old_password';
  static const String newPassword = 'new_password';
  static const String confirmPassword = 'confirm_password';

  // ── Profile Update ────────────────────────────────────────────────────────
  static const String bankAccountNumber = 'bank_account_number';
  static const String bankName = 'bank_name';
  static const String accountName = 'account_name';
  static const String ifscCode = 'ifsc_code';
  static const String otherPaymentInformation = 'other_payment_information';

  // ── FCM ───────────────────────────────────────────────────────────────────
  static const String fcmId = 'fcm_id';

  // ── Orders / Misc ─────────────────────────────────────────────────────────
  static const String orderId = 'order_id';
  static const String orderStatus = 'order_status';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String isAvailable = 'is_available';
  static const String orderItemId = 'order_item_id';

  // ── Return Requests ───────────────────────────────────────────────────────
  static const String isCompleted = 'is_completed';

  // ── Pagination & Filters ──────────────────────────────────────────────────
  static const String offset = 'offset';
  static const String limit = 'limit';
  static const String search = 'search';

  // ── Date Filters ──────────────────────────────────────────────────────────
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';

  // ── Wallet ────────────────────────────────────────────────────────────────
  static const String amount = 'amount';
  static const String typeId = 'type_id';

  // ── Language Settings ────────────────────────────────────────────────────────
  static const String systemType = 'system_type';
  static const String id = 'id';
  static const String isDefault = 'is_default';

  // ── Notification / Mail Settings ──────────────────────────────────────────
  static const String preferences = 'preferences';
  static const String key = 'key';
  static const String channels = 'channels';
  static const String mail = 'mail';
  static const String push = 'push';
  static const String sms = 'sms';

  // ── Chat ──────────────────────────────────────────────────────────────────
  static const String conversationId = 'conversation_id';
  static const String images = 'images[]';
  static const String audios = 'audios[]';
  static const String videos = 'videos[]';
  static const String files = 'files[]';
  static const String socketId = 'socket_id';
  static const String channelName = 'channel_name';

  // ── App Mode (Maintenance Window) ────────────────────────────────────────
  static const String appModeDeliveryBoyStart = 'app_mode_delivery_boy_start';
  static const String appModeDeliveryBoyEnd = 'app_mode_delivery_boy_end';
}
