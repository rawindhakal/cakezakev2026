import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/utils/force_update_helper.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'app_text.dart';
import 'app_button.dart';

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
              width: 60,
              height: 60,
              alignment: .center,
              decoration: AppDecorations.box(
                color: context.cs.primary.withValues(alpha: 0.1),
                shape: .circle,
              ),
              child: AppSvgIcon(
                AssetsConstants.forceUpdateIcon,
                color: context.cs.primary,
                size: 30,
              ),
            ),
            AppText(
              _isForce
                  ? context.translate(LanguageLabelKeys.updateRequired)
                  : context.translate(LanguageLabelKeys.updateAvailable),
              style: context.tt.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: .center,
            ),
          ],
        ),
        content: AppText(
          _isForce
              ? context.translate(LanguageLabelKeys.updateRequiredMessage)
              : context.translate(LanguageLabelKeys.updateAvailableMessage),
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
                    label: context.translate(LanguageLabelKeys.later),
                    variant: AppButtonVariant.outline,
                    color: context.cs.onSurfaceVariant,
                    height: 38,
                    fontSize: 12,
                    onPressed: () {
                      AppNavigator.pop(context);
                      onContinue();
                    },
                  ),
                ),
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.updateNow),
                  height: 38,
                  fontSize: 12,
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
