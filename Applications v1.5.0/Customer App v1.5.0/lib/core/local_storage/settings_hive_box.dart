import 'dart:convert';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/hive_box_keys.dart';

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

  // ── App Settings ──────────────────────────────────────────────────────────

  Future<void> saveAppSettings(AppSettingsData settings) async {
    await _box.put(kAppSettings, jsonEncode(settings.toJson()));
  }

  AppSettingsData? getAppSettings() {
    final raw = _box.get(kAppSettings) as String?;
    if (raw == null) return null;
    try {
      return AppSettingsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  int get maxCartItemsCount {
    final count = getAppSettings()?.maxCartItemsCount;
    return int.tryParse(count ?? '') ?? 0;
  }

  Future<void> clearAppSettings() async => _box.delete(kAppSettings);

  // ── Translations ──────────────────────────────────────────────────────────

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

  // ── Channel ───────────────────────────────────────────────────────────────

  Future<void> setChannel(String channel) => _box.put(kChannel, channel);

  String get channel =>
      _box.get(kChannel, defaultValue: AppConstants.quick) as String;

  /// Fires on every channel write (home toggle, server-forced mode, zone
  /// change) so screens outside Home can follow the active channel.
  ValueListenable<Box> get channelListenable =>
      _box.listenable(keys: [kChannel]);

  // ── Spin wheel ────────────────────────────────────────────────────────────

  String get spinWheelLastShownDate =>
      _box.get(kSpinWheelLastShownDate, defaultValue: '') as String;

  Future<void> setSpinWheelLastShownDate(String date) =>
      _box.put(kSpinWheelLastShownDate, date);

  /// Null when there's no spin currently in flight / awaiting retry.
  String? get spinWheelPendingRequestToken =>
      _box.get(kSpinWheelPendingRequestToken) as String?;

  Future<void> setSpinWheelPendingRequestToken(String token) =>
      _box.put(kSpinWheelPendingRequestToken, token);

  Future<void> clearSpinWheelPendingRequestToken() =>
      _box.delete(kSpinWheelPendingRequestToken);

  // ── Store closed ──────────────────────────────────────────────────────────

  Future<void> setStoreClosed(int storeClosed) =>
      _box.put(kStoreClosed, storeClosed);

  // 1 = closed, 0 = open. Default 0 (open) until API says otherwise.
  int get storeClosed => _box.get(kStoreClosed, defaultValue: 0) as int;

  // Quick-commerce-only closure flag — ecommerce channel is unaffected.
  bool get isStoreClosedQuick =>
      storeClosed == 1 && channel == AppConstants.quick;

  // ── Onboarding ────────────────────────────────────────────────────────────

  bool get onboardingSeen =>
      _box.get(kOnboardingSeen, defaultValue: false) as bool;

  Future<void> setOnboardingSeen() => _box.put(kOnboardingSeen, true);

  // ── Maintenance dialog ────────────────────────────────────────────────────

  String get maintenanceDialogDismissedWindow =>
      _box.get(kMaintenanceDialogDismissedWindow, defaultValue: '') as String;

  Future<void> setMaintenanceDialogDismissedWindow(String window) =>
      _box.put(kMaintenanceDialogDismissedWindow, window);

  // ── User location ─────────────────────────────────────────────────────────

  Future<void> saveUserLocation({
    required String latitude,
    required String longitude,
    String? label,
    String? address,
    String? pincode,
  }) async {
    await _box.putAll({
      kUserLatitude: latitude,
      kUserLongitude: longitude,
      kLocationLabel: label ?? locationLabel,
      kLocationAddress: address ?? locationAddress,
      kUserPincode: pincode ?? userPincode,
    });
  }

  String get userLatitude =>
      _box.get(kUserLatitude, defaultValue: '0') as String;
  String get userLongitude =>
      _box.get(kUserLongitude, defaultValue: '0') as String;
  String get userPincode => _box.get(kUserPincode, defaultValue: '') as String;
  String get locationLabel =>
      _box.get(kLocationLabel, defaultValue: '') as String;
  String get locationAddress =>
      _box.get(kLocationAddress, defaultValue: '') as String;
  bool get hasLocation => userLatitude != '0' && userLatitude.isNotEmpty;

  // ── Date/time format (from settings/country_setting api) ─────────────────

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

  // ── Zone ─────────────────────────────────────────────────────────────────

  Future<void> saveZoneId(int? id) => _box.put(kZoneId, id);

  int? get zoneId => _box.get(kZoneId) as int?;

  // ── Country ──────────────────────────────────────────────────────────────

  Future<void> saveSelectedCountryId(int? id) =>
      _box.put(kSelectedCountryId, id);

  int? get selectedCountryId => _box.get(kSelectedCountryId) as int?;

  // ── Google Places cache ───────────────────────────────────────────────────

  Future<void> cachePlaceAutocomplete(
    String query,
    Map<String, dynamic> data,
  ) => _box.put(
    '$kPlacesAutocompletePrefix${query.toLowerCase()}',
    jsonEncode(data),
  );

  Map<String, dynamic>? getCachedPlaceAutocomplete(String query) {
    final raw =
        _box.get('$kPlacesAutocompletePrefix${query.toLowerCase()}') as String?;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> cachePlaceDetails(String placeId, Map<String, dynamic> data) =>
      _box.put('$kPlaceDetailsPrefix$placeId', jsonEncode(data));

  Map<String, dynamic>? getCachedPlaceDetails(String placeId) {
    final raw = _box.get('$kPlaceDetailsPrefix$placeId') as String?;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
