import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/cubit/logout_cubit.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';

/// Opens the confirmation dialog for logging the rider out.
void showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => BlocProvider(
      create: (_) => LogoutCubit(),
      child: BlocConsumer<LogoutCubit, LogoutState>(
        listener: (ctx, state) {
          if (state is LogoutLoaded) {
            AppNavigator.pop(dialogContext);
            AppNavigator.pushNamedAndRemoveUntil(context, RouteNames.login);
          } else if (state is LogoutError) {
            AppNavigator.pop(dialogContext);
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (ctx, state) {
          final isLoading = state is LogoutLoading;
          return AppConfirmDialog(
            title: context.translate(LanguageLabelKeys.logout),
            message: context.translate(LanguageLabelKeys.areSureLogout),
            cancelLabel: context.translate(LanguageLabelKeys.keepLogin),
            confirmLabel: context.translate(LanguageLabelKeys.logoutAnyway),
            swapButtonEmphasis: true,
            isLoading: isLoading,
            onCancel: () => AppNavigator.pop(dialogContext),
            onConfirm: () => ctx.read<LogoutCubit>().logout(),
          );
        },
      ),
    ),
  );
}
