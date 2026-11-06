import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/password_requirements_checklist.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:customer/utils/password_policy.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPasswordSection extends StatefulWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSubmit;
  final String submitLabel;

  const ForgotPasswordPasswordSection({
    super.key,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSubmit,
    required this.submitLabel,
  });

  @override
  State<ForgotPasswordPasswordSection> createState() =>
      _ForgotPasswordPasswordSectionState();
}

class _ForgotPasswordPasswordSectionState
    extends State<ForgotPasswordPasswordSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        AppTextField(
          controller: widget.passwordController,
          labelText: context.translate(LanguageLabelKeys.newPassword),
          hintText: context.translate(LanguageLabelKeys.enterNewPassword),
          isPassword: true,
          validator: (v) => v.validateNewPassword(context),
        ),
        AppSpacing.h8,
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.passwordController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : PasswordRequirementsChecklist(
                  password: value.text,
                  policy: PasswordPolicy.fromSettings(),
                ),
        ),
        AppSpacing.h16,
        AppTextField(
          controller: widget.confirmPasswordController,
          labelText: context.translate(LanguageLabelKeys.confirmPassword),
          hintText: context.translate(LanguageLabelKeys.reEnterPassword),
          isPassword: true,
          validator: (v) => v.validateConfirmPassword(
            context,
            widget.passwordController.text,
          ),
        ),
        AppSpacing.h28,
        AppButton(
          label: widget.submitLabel,
          isLoading: widget.isLoading,
          onPressed: widget.isLoading ? null : widget.onSubmit,
        ),
      ],
    );
  }
}
