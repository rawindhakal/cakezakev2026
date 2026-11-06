import 'dart:io';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/utils/app_logger.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../commons/widgets/app_text.dart';
import '../../commons/widgets/app_button.dart';

/// Whether an app update is not needed, optional, or mandatory for the current session.
enum UpdateStatus { none, optional, force }

/// Compares the installed app version against server-configured minimum versions to decide update status.
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
    } catch (e) {
      logDebug(() => 'ForceUpdateHelper._isOutdated failed: $e');
    }
    return false;
  }

  /// Determines whether the installed app version requires an optional or forced update.
  static Future<UpdateStatus> getStatus(AppSettingsData data) async {
    try {
      final appVersion = (await PackageInfo.fromPlatform()).version;

      if (Platform.isAndroid) {
        if (data.isVersionSystemOnDeliveryBoy != '1') return UpdateStatus.none;
        if (!_isOutdated(appVersion, data.currentVersionDeliveryBoy ?? '')) {
          return UpdateStatus.none;
        }
        return data.requiredForceUpdateDeliveryBoy == '1'
            ? UpdateStatus.force
            : UpdateStatus.optional;
      }

      if (Platform.isIOS) {
        if (data.iosIsVersionSystemOnDeliveryBoy != '1') {
          return UpdateStatus.none;
        }
        if (!_isOutdated(appVersion, data.iosCurrentVersionDeliveryBoy ?? '')) {
          return UpdateStatus.none;
        }
        return data.iosRequiredForceUpdateDeliveryBoy == '1'
            ? UpdateStatus.force
            : UpdateStatus.optional;
      }
    } catch (e) {
      logDebug(() => 'ForceUpdateHelper.getStatus failed: $e');
    }
    return UpdateStatus.none;
  }

  /// Opens the platform app store listing so the user can update.
  static Future<void> launchStore(AppSettingsData data) async {
    final url = Platform.isIOS
        ? (data.deliveryBoyAppstoreUrl ?? '')
        : (data.deliveryBoyPlaystoreUrl ?? '');
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      logDebug(() => 'ForceUpdateHelper.launchStore failed: $e');
    }
  }
}

/// Non-dismissible dialog prompting the user to update, blocking the app when [UpdateStatus.force].
class ForceUpdateDialog extends StatelessWidget {
  final AppSettingsData data;
  final UpdateStatus status;
  final VoidCallback onContinue;

  const ForceUpdateDialog({
    super.key,
    required this.data,
    required this.status,
    required this.onContinue,
  });

  bool get _isForce => status == UpdateStatus.force;

  static Future<void> show({
    required BuildContext context,
    required AppSettingsData data,
    required UpdateStatus status,
    required VoidCallback onContinue,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ForceUpdateDialog(data: data, status: status, onContinue: onContinue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: context.cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        titlePadding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingXL,
          ThemeConstants.paddingXL,
          ThemeConstants.paddingXL,
          0,
        ),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingXL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingXL,
          0,
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        title: Column(
          spacing: ThemeConstants.spaceM,
          children: [
            Container(
              width: context.screenWidth * 0.16,
              height: context.screenWidth * 0.16,
              alignment: .center,
              decoration: AppDecorations.circle(
                color: context.cs.primary.withValues(alpha: 0.1),
              ),
              child: AppSvgIcon(
                AssetsConstants.forceUpdateIcon,
                color: context.cs.primary,
                size: context.screenWidth * 0.08,
              ),
            ),
            AppText(
              context.translate(
                _isForce
                    ? LanguageLabelKeys.updateRequiredTitle
                    : LanguageLabelKeys.updateAvailableTitle,
              ),
              style: context.tt.titleMedium,
              textAlign: .center,
            ),
          ],
        ),
        content: AppText(
          context.translate(
            _isForce
                ? LanguageLabelKeys.updateRequiredMessage
                : LanguageLabelKeys.updateAvailableMessage,
          ),
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: .center,
        ),
        actionsAlignment: .center,
        actions: [
          // Same button row as AppConfirmDialog (e.g. logout) so dialogs match.
          Row(
            spacing: ThemeConstants.spaceM,
            children: [
              if (!_isForce)
                Expanded(
                  child: AppButton(
                    label: context.translate(LanguageLabelKeys.updateLater),
                    variant: AppButtonVariant.outline,
                    color: context.cs.onSurfaceVariant,
                    height: context.screenHeight * 0.047,
                    fontSize: 13,
                    onPressed: () {
                      AppNavigator.pop(context);
                      onContinue();
                    },
                  ),
                ),
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.updateNow),
                  height: context.screenHeight * 0.047,
                  fontSize: 13,
                  onPressed: () => ForceUpdateHelper.launchStore(data),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
