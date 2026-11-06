import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';

class ClarityService {
  ClarityService._();

  /// Project id from cached settings (`clarity_project_id_customer`),
  /// falls back to [AppConfig.clarityProjectId] when empty/unset.
  static ClarityConfig get config {
    final customProjectId = SettingsHiveBox.instance
        .getAppSettings()
        ?.clarityProjectIdCustomer;
    final projectId =
        (customProjectId != null && customProjectId.trim().isNotEmpty)
        ? customProjectId
        : AppConfig.clarityProjectId;
    return ClarityConfig(projectId: projectId);
  }

  static void sendCustomEvent(String name) => Clarity.sendCustomEvent(name);

  static void setCustomTag(String key, String value) =>
      Clarity.setCustomTag(key, value);

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
