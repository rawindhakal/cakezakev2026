import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class SignInEmailForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onForgotPassword;

  const SignInEmailForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onForgotPassword,
  });

  @override
  State<SignInEmailForm> createState() => _SignInEmailFormState();
}

class _SignInEmailFormState extends State<SignInEmailForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          controller: widget.emailController,
          labelText: context.translate(LanguageLabelKeys.email),
          isRequired: true,
          hintText: context.translate(LanguageLabelKeys.enterEmail),
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v.validateEmail(context),
        ),
        AppSpacing.h16,
        AppTextField(
          controller: widget.passwordController,
          labelText: context.translate(LanguageLabelKeys.password),
          isRequired: true,
          hintText: context.translate(LanguageLabelKeys.enterPassword),
          isPassword: true,
          validator: (v) => v.validateRequiredField(context),
        ),
        AppSpacing.h8,
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: widget.onForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsetsDirectional.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: AppText(
              context.translate(LanguageLabelKeys.forgotPassword),
              style: context.tt.labelMedium?.copyWith(
                color: context.cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
