import 'dart:io';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateStatus { none, optional, force }

class ForceUpdateHelper {
  static bool _isOutdated(String appVer, String serverVer) {
    try {
      final app = appVer.split('.').map(int.tryParse).toList();
      final srv = serverVer.split('.').map(int.tryParse).toList();
      for (int i = 0; i < 3; i++) {
        final a = i < app.length ? (app[i] ?? 0) : 0;
        final s = i < srv.length ? (srv[i] ?? 0) : 0;
        if (a < s) return true;
        if (a > s) return false;
      }
    } catch (_) {}
    return false;
  }

  static Future<UpdateStatus> getStatus(AppSettingsData data) async {
    try {
      final appVersion = (await PackageInfo.fromPlatform()).version;

      final isVersionSystemOn = Platform.isIOS
          ? data.iosIsVersionSystemOnCustomer
          : data.isVersionSystemOnCustomer;
      final serverVersion = Platform.isIOS
          ? data.iosCurrentVersionCustomer
          : data.currentVersionCustomer;
      final requiredForceUpdate = Platform.isIOS
          ? data.iosRequiredForceUpdateCustomer
          : data.requiredForceUpdateCustomer;

      if (isVersionSystemOn != '1') return UpdateStatus.none;
      if (!_isOutdated(appVersion, serverVersion ?? '')) {
        return UpdateStatus.none;
      }
      return requiredForceUpdate == '1'
          ? UpdateStatus.force
          : UpdateStatus.optional;
    } catch (_) {}
    return UpdateStatus.none;
  }

  static Future<void> launchStore(AppSettingsData data) async {
    final url = Platform.isIOS
        ? (data.appstoreUrl ?? '')
        : (data.playstoreUrl ?? '');
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
