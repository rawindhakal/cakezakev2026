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
const String kUserProfile = 'user_profile';
const String kUserDataJson = 'user_data_json';
const String kFcmToken = 'fcm_token';
const String kAdminConversationId = 'admin_conversation_id';
const String kOrderConversationIdPrefix = 'order_conversation_id_';

// ── SettingsHiveBox keys ──────────────────────────────────────────────────
// theme | language | app settings | translations
const String kThemeMode = 'theme_mode';
const String kLanguageCode = 'language_code';
const String kLanguageId = 'language_id';
const String kLanguageType = 'language_type';
const String kLanguageUserSelected = 'language_user_selected';
const String kAppSettings = 'app_settings';
const String kTranslationsLangId = 'translations_lang_id';
const String kTranslationsJson = 'translations_json';
const String kDateFormat = 'date_format';
const String kTimeFormat = 'time_format';

// ── Maintenance dialog ────────────────────────────────────────────────────
/// Identifies the scheduled-maintenance window (start+end) the user last
/// dismissed via the "OK" button, so it isn't shown again for that same
/// window on future app opens — but shows again once a new window differs.
const String kMaintenanceDialogDismissedWindow =
    'maintenance_dialog_dismissed_window';
