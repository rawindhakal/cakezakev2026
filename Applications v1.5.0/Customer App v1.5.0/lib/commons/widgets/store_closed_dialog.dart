import 'package:customer/commons/widgets/app_confirm_dialog.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

void showStoreClosedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AppConfirmDialog(
      icon: AppConfirmDialogIcon.warning,
      title: context.translate(LanguageLabelKeys.currentlyNotAcceptingOrders),
      message: '',
      confirmLabel: context.translate(LanguageLabelKeys.ok),
      onConfirm: () => AppNavigator.pop(dialogContext),
    ),
  );
}
