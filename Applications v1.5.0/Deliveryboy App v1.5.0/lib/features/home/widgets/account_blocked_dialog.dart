import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

void showAccountBlockedDialog(BuildContext context, {String? remark}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AppConfirmDialog(
        isDestructive: true,
        title: context.translate(LanguageLabelKeys.accountBlocked),
        message: context.translate(LanguageLabelKeys.accountBlockedMessage),
        confirmLabel: context.translate(LanguageLabelKeys.ok),
        extraContent: (remark != null && remark.isNotEmpty)
            ? Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.all(10),
                decoration: AppDecorations.card(
                  color: context.cs.onErrorContainer.withValues(alpha: 0.12),
                  borderRadius: AppRadius.r8,
                  border: Border.all(
                    color: context.cs.error.withValues(alpha: 0.3),
                  ),
                ),
                child: AppText(
                  remark,
                  style: context.tt.labelMedium?.copyWith(
                    color: context.cs.error,
                  ),
                ),
              )
            : null,
        onConfirm: () async {
          await AuthRepository().logout().catchError((_) {});
          await AuthHiveBox.instance.clearAuth();
          if (context.mounted) {
            AppNavigator.pushNamedAndRemoveUntil(context, RouteNames.login);
          }
        },
      ),
    ),
  );
}
