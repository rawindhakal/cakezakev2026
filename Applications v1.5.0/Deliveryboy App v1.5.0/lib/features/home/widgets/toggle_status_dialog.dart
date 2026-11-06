import 'package:deliveryboy/commons/utils/app_haptics.dart';
import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/navigation_service.dart';
import '../cubit/delivery_boy_status_cubit.dart';

/// Confirms going online/offline before calling [DeliveryBoyStatusCubit.toggleOnline].
/// [goingOnline] reflects the state the rider is switching *to*.
Future<void> showToggleStatusDialog(
  BuildContext context, {
  required bool goingOnline,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AppConfirmDialog(
      title: context.translate(LanguageLabelKeys.changeStatus),
      message: context.translate(
        goingOnline
            ? LanguageLabelKeys.confirmGoOnline
            : LanguageLabelKeys.confirmGoOffline,
      ),
      cancelLabel: context.translate(LanguageLabelKeys.cancel),
      confirmLabel: context.translate(
        goingOnline ? LanguageLabelKeys.goOnline : LanguageLabelKeys.goOffline,
      ),
      onCancel: () => AppNavigator.pop(dialogContext),
      onConfirm: () {
        AppHaptics.tap();
        AppNavigator.pop(dialogContext);
        context.read<DeliveryBoyStatusCubit>().toggleOnline();
      },
    ),
  );
}
