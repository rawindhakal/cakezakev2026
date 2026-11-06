import 'dart:convert';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/hive_box_keys.dart';

/// Hive-backed store for user preferences: theme, language, app settings, and translations cache.
class SettingsHiveBox {
  SettingsHiveBox._();
  static final SettingsHiveBox instance = SettingsHiveBox._();

  Box get _box => Hive.box(settingsBox);

  // ── Theme ─────────────────────────────────────────────────────────────────

  Future<void> setThemeMode(String mode) => _box.put(kThemeMode, mode);

  String get savedThemeMode =>
      _box.get(kThemeMode, defaultValue: 'light') as String;

  // ── Language ──────────────────────────────────────────────────────────────

  Future<void> setLanguageCode(String code) => _box.put(kLanguageCode, code);

  String get languageCode =>
      _box.get(kLanguageCode, defaultValue: AppConfig.defaultLanguageCode)
          as String;

  Future<void> setLanguageId(String id) => _box.put(kLanguageId, id);

  String get languageId => _box.get(kLanguageId, defaultValue: '') as String;

  Future<void> setLanguageType(String type) => _box.put(kLanguageType, type);

  String get languageType =>
      _box.get(kLanguageType, defaultValue: 'ltr') as String;

  /// Whether the current language was picked by the user (vs auto-selected
  /// from the backend's default flag). Only a user pick should stay sticky
  /// across app launches — an auto-picked default must keep following the
  /// backend's `is_default` flag if it changes later.
  Future<void> setLanguageUserSelected(bool value) =>
      _box.put(kLanguageUserSelected, value);

  bool get languageUserSelected =>
      _box.get(kLanguageUserSelected, defaultValue: false) as bool;

  // ── App Settings ──────────────────────────────────────────────────────────

  Future<void> saveAppSettings(AppSettingsData settings) async {
    await _box.put(kAppSettings, jsonEncode(settings.toJson()));
  }

  /// Returns the cached app settings, or null if none were saved or parsing failed.
  AppSettingsData? getAppSettings() {
    final raw = _box.get(kAppSettings) as String?;
    if (raw == null) return null;
    try {
      return AppSettingsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAppSettings() async => _box.delete(kAppSettings);

  // ── Date/time format ──────────────────────────────────────────────────────

  /// Saves the given date and/or time format strings, leaving unset ones unchanged.
  Future<void> saveDateTimeFormat({
    String? dateFormat,
    String? timeFormat,
  }) async {
    if (dateFormat != null && dateFormat.isNotEmpty) {
      await _box.put(kDateFormat, dateFormat);
    }
    if (timeFormat != null && timeFormat.isNotEmpty) {
      await _box.put(kTimeFormat, timeFormat);
    }
  }

  String get dateFormat =>
      _box.get(kDateFormat, defaultValue: 'd/m/Y') as String;
  String get timeFormat =>
      _box.get(kTimeFormat, defaultValue: 'h:i A') as String;

  // Delivery boy has no user location; default to '0' for country_setting API
  String get userLatitude => '0';
  String get userLongitude => '0';

  // ── Translations ──────────────────────────────────────────────────────────

  /// Caches the translation map for the given language ID.
  Future<void> saveTranslations({
    required String languageId,
    required Map<dynamic, dynamic> data,
  }) async {
    await _box.put(kTranslationsLangId, languageId);
    await _box.put(
      kTranslationsJson,
      jsonEncode(Map<String, dynamic>.from(data)),
    );
  }

  String get translationsLangId =>
      _box.get(kTranslationsLangId, defaultValue: '') as String;

  Map<dynamic, dynamic>? get translationsJson {
    final raw = _box.get(kTranslationsJson) as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<dynamic, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Maintenance dialog ────────────────────────────────────────────────────

  String get maintenanceDialogDismissedWindow =>
      _box.get(kMaintenanceDialogDismissedWindow, defaultValue: '') as String;

  Future<void> setMaintenanceDialogDismissedWindow(String window) =>
      _box.put(kMaintenanceDialogDismissedWindow, window);
}
