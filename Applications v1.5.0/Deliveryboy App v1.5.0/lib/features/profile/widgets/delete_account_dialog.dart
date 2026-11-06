import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/cubit/delete_account_cubit.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';

/// Opens the confirmation dialog for deleting the rider's account.
void showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => BlocProvider(
      create: (_) => DeleteAccountCubit(),
      child: BlocConsumer<DeleteAccountCubit, DeleteAccountState>(
        listener: (ctx, state) {
          if (state is DeleteAccountLoaded) {
            AppNavigator.pop(dialogContext);
            AppNavigator.pushNamedAndRemoveUntil(context, RouteNames.login);
          } else if (state is DeleteAccountError) {
            AppNavigator.pop(dialogContext);
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (ctx, state) {
          final isLoading = state is DeleteAccountLoading;
          return AppConfirmDialog(
            isDestructive: true,
            title: context.translate(LanguageLabelKeys.deleteAccount),
            message: context.translate(LanguageLabelKeys.deleteAccountWarning),
            cancelLabel: context.translate(LanguageLabelKeys.cancel),
            confirmLabel: context.translate(LanguageLabelKeys.delete),
            isLoading: isLoading,
            onCancel: () => AppNavigator.pop(dialogContext),
            onConfirm: () => ctx.read<DeleteAccountCubit>().deleteAccount(),
          );
        },
      ),
    ),
  );
}
