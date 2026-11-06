import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class SignInPhoneForm extends StatefulWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool isPhonePasswordEnabled;
  final String? phoneError;
  final CountriesData? selectedCountry;
  final void Function(String number, String countryCode) onPhoneChanged;
  final ValueChanged<CountriesData> onCountryChanged;
  final VoidCallback onForgotPassword;

  const SignInPhoneForm({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.isPhonePasswordEnabled,
    this.phoneError,
    required this.selectedCountry,
    required this.onPhoneChanged,
    required this.onCountryChanged,
    required this.onForgotPassword,
  });

  @override
  State<SignInPhoneForm> createState() => _SignInPhoneFormState();
}

class _SignInPhoneFormState extends State<SignInPhoneForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.phoneNumber),
          isRequired: true,
          style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.h8,
        ApiCountryPhoneField(
          controller: widget.phoneController,
          selectedCountry: widget.selectedCountry,
          hintText: context.translate(LanguageLabelKeys.enterPhoneNumber),
          errorText: widget.phoneError,
          onCountryChanged: widget.onCountryChanged,
          onChanged: (number) => widget.onPhoneChanged(
            number,
            formatDialCode(widget.selectedCountry?.dialCode),
          ),
        ),
        if (widget.isPhonePasswordEnabled) ...[
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
      ],
    );
  }
}
