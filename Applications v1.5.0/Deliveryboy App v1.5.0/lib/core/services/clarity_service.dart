import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';

/// Thin wrapper around Microsoft Clarity session recording/analytics.
class ClarityService {
  ClarityService._();

  /// Project id from cached settings (`clarity_project_id_customer`),
  /// falls back to [AppConfig.clarityProjectId] when empty/unset.
  static ClarityConfig get config {
    final customProjectId = SettingsHiveBox.instance
        .getAppSettings()
        ?.clarityProjectIdDeliveryBoy;
    final projectId =
        (customProjectId != null && customProjectId.trim().isNotEmpty)
        ? customProjectId
        : AppConfig.clarityProjectId;
    return ClarityConfig(projectId: projectId);
  }

  /// Sends a custom named event to Clarity.
  static void sendCustomEvent(String name) => Clarity.sendCustomEvent(name);

  /// Sets a custom key/value tag on the current Clarity session.
  static void setCustomTag(String key, String value) =>
      Clarity.setCustomTag(key, value);

  /// Updates the screen name reported for the current Clarity session.
  static void setCurrentScreenName(String? screenName) =>
      Clarity.setCurrentScreenName(screenName);

  static void pause() => Clarity.pause();

  static void resume() => Clarity.resume();

  /// Applies the `clarity_status_customer` flag from settings ("1" = on, else off).
  static void applyStatus(String? status) {
    if (status == '1') {
      resume();
    } else {
      pause();
    }
  }
}
