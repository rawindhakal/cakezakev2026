// ── Box names ─────────────────────────────────────────────────────────────
const String authBox = 'auth';
const String settingsBox = 'settings';

/// ETag-tagged response bodies for conditional GETs (see ETagInterceptor).
const String etagCacheBox = 'http_etag_cache';

// ── Secure storage keys ───────────────────────────────────────────────────
/// Key under which the Hive AES encryption key is kept in OS secure storage
/// (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on Android).
const String kHiveEncryptionKey = 'hive_encryption_key';

// ── AuthHiveBox keys ──────────────────────────────────────────────────────
// token | user data | login state | FCM token
const String kToken = 'token';
const String kIsLoggedIn = 'is_logged_in';
const String kUserId = 'user_id';
const String kUserName = 'user_name';
const String kUserMobile = 'user_mobile';
const String kUserEmail = 'user_email';
const String kUserDataJson = 'user_data_json';
const String kFcmToken = 'fcm_token';
const String kAdminConversationId = 'admin_conversation_id';
const String kOrderConversationIdPrefix = 'order_conversation_id_';
const String kOrderAdminConversationIdPrefix = 'order_admin_conversation_id_';

// ── SettingsHiveBox keys ──────────────────────────────────────────────────
// theme | language | app settings | translations
const String kThemeMode = 'theme_mode';
const String kLanguageCode = 'language_code';
const String kLanguageId = 'language_id';
const String kLanguageType = 'language_type';
const String kAppSettings = 'app_settings';
const String kTranslationsLangId = 'translations_lang_id';
const String kTranslationsJson = 'translations_json';
const String kUserLatitude = 'user_latitude';
const String kUserLongitude = 'user_longitude';
const String kLocationLabel = 'location_label';
const String kLocationAddress = 'location_address';
const String kUserPincode = 'user_pincode';
const String kDateFormat = 'date_format';
const String kTimeFormat = 'time_format';

// ── Onboarding ────────────────────────────────────────────────────────────
const String kOnboardingSeen = 'onboarding_seen';

// ── Maintenance dialog ────────────────────────────────────────────────────
/// Identifies the scheduled-maintenance window (start+end) the user last
/// dismissed via the "OK" button, so it isn't shown again for that same
/// window on future app opens — but shows again once a new window differs.
const String kMaintenanceDialogDismissedWindow =
    'maintenance_dialog_dismissed_window';

// ── Channel ───────────────────────────────────────────────────────────────
const String kChannel = 'channel';

// ── Spin wheel ────────────────────────────────────────────────────────────
/// Date (yyyy-MM-dd) the home spin wheel was last shown — one spin per day.
const String kSpinWheelLastShownDate = 'spin_wheel_last_shown_date';

/// Pending `spin_wheel/spin` request_token (UUID v4) — set right before
/// calling the spin API, cleared only on a successful response. Kept on
/// error/timeout/app-kill so a retry reuses the SAME token, letting the
/// backend recognize and dedupe a previously-interrupted spin.
const String kSpinWheelPendingRequestToken = 'spin_wheel_pending_request_token';

// ── Store closed ──────────────────────────────────────────────────────────
const String kStoreClosed = 'store_closed';

// ── Zone ──────────────────────────────────────────────────────────────────
const String kZoneId = 'zone_id';

// ── Country ───────────────────────────────────────────────────────────────
const String kSelectedCountryId = 'selected_country_id';

// ── Guest Cart ────────────────────────────────────────────────────────────
const String guestCartBox = 'guest_cart';
const String kQuickCartEntriesJson = 'quick_cart_entries';
const String kEcommerceCartEntriesJson = 'ecommerce_cart_entries';
// Add-on module: guest add-on lines (dish + answers) per channel.
const String kQuickAddonLinesJson = 'quick_addon_lines';
const String kEcommerceAddonLinesJson = 'ecommerce_addon_lines';

// ── Google Places cache keys ───────────────────────────────────────────────
const String kPlacesAutocompletePrefix = 'places_ac_';
const String kPlaceDetailsPrefix = 'place_details_';

// ── Recent product searches ────────────────────────────────────────────────
const String kRecentProductSearches = 'recent_product_searches';
