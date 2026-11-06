import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_confirm_dialog.dart';
import 'package:customer/commons/widgets/password_requirements_checklist.dart';
import 'package:customer/utils/password_policy.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/auth/cubits/change_password_cubit.dart';
import 'package:customer/features/auth/cubits/delete_account_cubit.dart';
import 'package:customer/features/auth/cubits/logout_cubit.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

void showChangePasswordSheet(
  BuildContext context, {
  AuthRepository? repository,
}) {
  showAppBottomSheet(
    context,
    showDragHandle: false,
    padding: null,
    builder: (sheetContext) => BlocProvider(
      create: (_) => ChangePasswordCubit(repository: repository),
      child: _ChangePasswordSheetBody(parentContext: context),
    ),
  );
}

class _ChangePasswordSheetBody extends StatefulWidget {
  final BuildContext parentContext;

  const _ChangePasswordSheetBody({required this.parentContext});

  @override
  State<_ChangePasswordSheetBody> createState() =>
      _ChangePasswordSheetBodyState();
}

class _ChangePasswordSheetBodyState extends State<_ChangePasswordSheetBody> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ChangePasswordCubit>().changePassword(
      oldPassword: _oldPasswordController.text.trim(),
      newPassword: _passwordController.text.trim(),
      newPasswordConfirmation: _confirmController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = context.keyboardInset;

    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listener: (ctx, state) async {
        if (state is ChangePasswordLoaded) {
          AppNavigator.pop(context);
          AppSnackBar.show(
            context: widget.parentContext,
            message: state.message,
            type: SnackBarType.success,
          );
          await AuthHiveBox.instance.clearAuth();
          if (widget.parentContext.mounted) {
            AppNavigator.pushNamedAndRemoveUntil(
              widget.parentContext,
              RouteNames.login,
            );
          }
        }
      },
      builder: (ctx, state) {
        final isLoading = state is ChangePasswordLoading;
        return SafeArea(
          bottom: true,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingXL,
              ThemeConstants.paddingL,
              bottomInset + ThemeConstants.paddingXXL,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: SlideAnimationList(
                  crossAxisAlignment: .start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: AppDecorations.dragHandle(
                          color: context.cs.outlineVariant,
                        ),
                      ),
                    ),
                    AppSpacing.h16,
                    AppText(
                      context.translate(LanguageLabelKeys.changePassword),
                      style: context.tt.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface,
                      ),
                    ),
                    AppSpacing.h4,
                    AppText(
                      context.translate(
                        LanguageLabelKeys.changePasswordLogoutWarning,
                      ),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h20,
                    AppText(
                      context.translate(LanguageLabelKeys.oldPassword),
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h8,
                    AppTextField(
                      controller: _oldPasswordController,
                      hintText: context.translate(
                        LanguageLabelKeys.enterCurrentPassword,
                      ),
                      isPassword: true,
                      validator: (v) => v.validateRequiredField(context),
                    ),
                    AppSpacing.h16,
                    AppText(
                      context.translate(LanguageLabelKeys.newPassword),
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h8,
                    AppTextField(
                      controller: _passwordController,
                      hintText: context.translate(
                        LanguageLabelKeys.enterNewPassword,
                      ),
                      isPassword: true,
                      validator: (v) => v.validatePassword(context),
                    ),
                    AppSpacing.h8,
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _passwordController,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : PasswordRequirementsChecklist(
                              password: value.text,
                              policy: PasswordPolicy.fromSettings(),
                            ),
                    ),
                    AppSpacing.h16,
                    AppText(
                      context.translate(LanguageLabelKeys.confirmPassword),
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h8,
                    AppTextField(
                      controller: _confirmController,
                      hintText: context.translate(
                        LanguageLabelKeys.reEnterPassword,
                      ),
                      isPassword: true,
                      validator: (v) => v.validateConfirmPassword(
                        context,
                        _passwordController.text.trim(),
                      ),
                    ),
                    if (state is ChangePasswordError) ...[
                      AppSpacing.h16,
                      AppText(
                        state.message,
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.error,
                        ),
                      ),
                    ],
                    AppSpacing.h24,
                    AppButton(
                      label: context.translate(
                        LanguageLabelKeys.changePassword,
                      ),
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void showLogoutDialog(BuildContext context, {AuthRepository? repository}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => BlocProvider(
      create: (_) => LogoutCubit(repository: repository),
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
            icon: AppConfirmDialogIcon.warning,
            title: context.translate(LanguageLabelKeys.logout),
            message: context.translate(LanguageLabelKeys.logoutConfirm),
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

void showDeleteAccountDialog(
  BuildContext context, {
  AuthRepository? repository,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => BlocProvider(
      create: (_) => DeleteAccountCubit(repository: repository),
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
            icon: AppConfirmDialogIcon.danger,
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
