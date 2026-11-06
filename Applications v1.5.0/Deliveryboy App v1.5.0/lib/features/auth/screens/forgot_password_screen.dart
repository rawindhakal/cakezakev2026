import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/forgot_password_cubit.dart';
import '../../../commons/widgets/app_button.dart';
import '../../../commons/widgets/app_text_field.dart';
import '../../../utils/input_validators.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Opens the bottom sheet for requesting a password reset link/OTP via email.
void showForgotPasswordSheet(BuildContext context) {
  showAppBottomSheet(
    context,
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingXL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingXL,
      ThemeConstants.paddingXXL,
    ),
    builder: (sheetContext) => BlocProvider(
      create: (_) => ForgotPasswordCubit(),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const _ForgotPasswordSheet(),
      ),
    ),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordCubit>().forgotPassword(
      _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
      listener: (context, state) {
        if (state is ForgotPasswordLoaded) {
          AppSnackBar.show(
            context: context,
            message: state.data,
            type: SnackBarType.success,
          );
          AppNavigator.pop(context);
        } else if (state is ForgotPasswordError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: SlideAnimationList(
              crossAxisAlignment: .start,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.forgotPasswordTitle),
                  style: context.tt.headlineSmall?.copyWith(
                    letterSpacing: -0.3,
                  ),
                ),
                AppSpacing.h6,
                AppText(
                  context.translate(LanguageLabelKeys.weWillSendLink),
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h24,
                AppText(
                  context.translate(LanguageLabelKeys.email),
                  style: context.tt.labelMedium?.copyWith(
                    color: context.cs.onSurface,
                  ),
                ),
                AppSpacing.h8,
                AppTextField(
                  controller: _emailController,
                  hintText: context.translate(
                    LanguageLabelKeys.enterEmailAddress,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v.validateEmail(context),
                ),
                AppSpacing.h28,
                AppButton(
                  label: context.translate(LanguageLabelKeys.submit),
                  isLoading: state is ForgotPasswordLoading,
                  onPressed: () => _submit(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
