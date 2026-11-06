import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class ForgotPasswordInputSection extends StatelessWidget {
  final bool isPhone;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final bool isLoading;
  final CountriesData? selectedCountry;
  final void Function(String countryCode) onCountryCodeChanged;
  final ValueChanged<CountriesData> onCountryChanged;
  final VoidCallback onSendOtp;

  const ForgotPasswordInputSection({
    super.key,
    required this.isPhone,
    required this.emailController,
    required this.phoneController,
    required this.isLoading,
    required this.selectedCountry,
    required this.onCountryCodeChanged,
    required this.onCountryChanged,
    required this.onSendOtp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      spacing: ThemeConstants.spaceXXL,
      children: [
        if (isPhone) _buildPhoneField(context) else _buildEmailField(context),
        AppButton(
          label: context.translate(LanguageLabelKeys.sendOtp),
          isLoading: isLoading,
          onPressed: isLoading ? null : onSendOtp,
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return AppTextField(
      controller: emailController,
      labelText: context.translate(LanguageLabelKeys.email),
      hintText: context.translate(LanguageLabelKeys.enterEmail),
      keyboardType: TextInputType.emailAddress,
      validator: (v) => v.validateEmail(context),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceS,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.phoneNumber),
          style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        ApiCountryPhoneField(
          controller: phoneController,
          selectedCountry: selectedCountry,
          hintText: context.translate(LanguageLabelKeys.enterPhoneNumber),
          onCountryChanged: (country) {
            onCountryChanged(country);
            onCountryCodeChanged(formatDialCode(country.dialCode));
          },
        ),
      ],
    );
  }
}
