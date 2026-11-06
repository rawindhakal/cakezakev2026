import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/password_requirements_checklist.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/auth/cubit/change_password_cubit.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/input_validators.dart';
import 'package:deliveryboy/utils/password_policy.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Opens the bottom sheet for changing the rider's account password.
void showChangePasswordSheet(BuildContext context) {
  showAppBottomSheet(
    context,
    padding: null,
    showDragHandle: false,
    builder: (sheetContext) => BlocProvider(
      create: (_) => ChangePasswordCubit(),
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
  bool _obscureOldPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
      password: _passwordController.text.trim(),
      confirmPassword: _confirmController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;
    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listener: (ctx, state) async {
        if (state is ChangePasswordLoaded) {
          AppNavigator.pop(context);
          AppSnackBar.show(
            context: widget.parentContext,
            message: state.data,
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
        final errorMessage = state is ChangePasswordError
            ? state.message
            : null;
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingXL, ThemeConstants.paddingL, bottomInset + 24),
          child: Form(
            key: _formKey,
            child: SlideAnimationList(
              crossAxisAlignment: .start,
              children: [
                Center(
                  child: Container(
                    width: context.screenWidth * 0.107,
                    height: context.screenHeight * 0.005,
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
                    color: context.cs.onSurface,
                  ),
                ),
                AppSpacing.h20,
                AppText(
                  context.translate(LanguageLabelKeys.oldPassword),
                  style: context.tt.labelMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h8,
                AppTextField(
                  controller: _oldPasswordController,
                  hintText: context.translate(
                    LanguageLabelKeys.enterOldPassword,
                  ),
                  obscureText: _obscureOldPassword,
                  suffixIcon: IconButton(
                    icon: AppSvgIcon(
                      _obscureOldPassword
                          ? AssetsConstants.passwordHideIcon
                          : AssetsConstants.passwordVisibleIcon,
                      size: ThemeConstants.iconM,
                      color: context.cs.onSurfaceVariant,
                    ),
                    onPressed: () => setState(
                      () => _obscureOldPassword = !_obscureOldPassword,
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? context.translate(LanguageLabelKeys.oldPasswordRequired)
                      : null,
                ),
                AppSpacing.h16,
                AppText(
                  context.translate(LanguageLabelKeys.newPassword),
                  style: context.tt.labelMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h8,
                AppTextField(
                  controller: _passwordController,
                  hintText: context.translate(
                    LanguageLabelKeys.enterNewPassword,
                  ),
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: AppSvgIcon(
                      _obscurePassword
                          ? AssetsConstants.passwordHideIcon
                          : AssetsConstants.passwordVisibleIcon,
                      size: ThemeConstants.iconM,
                      color: context.cs.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
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
                  style: context.tt.labelMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h8,
                AppTextField(
                  controller: _confirmController,
                  hintText: context.translate(
                    LanguageLabelKeys.reEnterNewPassword,
                  ),
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: AppSvgIcon(
                      _obscureConfirm
                          ? AssetsConstants.passwordHideIcon
                          : AssetsConstants.passwordVisibleIcon,
                      size: ThemeConstants.iconM,
                      color: context.cs.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) => v.validateConfirmPassword(
                    context,
                    _passwordController.text.trim(),
                  ),
                ),
                AppSpacing.h24,
                if (errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingM,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r10,
                      border: Border.all(
                        color: context.cs.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: ThemeConstants.spaceS,
                      children: [
                        AppSvgIcon(
                          AssetsConstants.dangerIcon,
                          color: context.cs.error,
                          size: ThemeConstants.iconS,
                        ),
                        Expanded(
                          child: AppText(
                            errorMessage,
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h16,
                ],
                AppButton(
                  label: context.translate(LanguageLabelKeys.updatePassword),
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
