import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/country_dropdown_field.dart';
import 'package:customer/commons/widgets/password_requirements_checklist.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:customer/utils/password_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/commons/widgets/app_text.dart';

class SignUpForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController referralController;
  final AuthType mode;
  final bool showEmail;
  final bool showPhone;
  final bool showPassword;
  final bool phoneReadOnly;
  final String? phoneError;
  final void Function(String number, String countryCode) onPhoneChanged;
  final CountriesData? selectedCountry;
  final ValueChanged<CountriesData> onCountryChanged;

  const SignUpForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.referralController,
    required this.mode,
    required this.showEmail,
    required this.showPhone,
    required this.showPassword,
    required this.phoneReadOnly,
    this.phoneError,
    required this.onPhoneChanged,
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  bool get _isSocial =>
      widget.mode == AuthType.google || widget.mode == AuthType.apple;

  bool get _isPhoneRequired => widget.mode != AuthType.email && !_isSocial;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AppTextField(
            controller: widget.nameController,
            labelText: context.translate(LanguageLabelKeys.fullName),
            isRequired: true,
            hintText: context.translate(LanguageLabelKeys.enterFullName),
            keyboardType: TextInputType.name,
            readOnly: _isSocial,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
            ],
            validator: (v) => v.validateName(context),
          ),
          AppSpacing.h16,

          if (widget.showEmail) ...[
            AppTextField(
              controller: widget.emailController,
              labelText: context.translate(LanguageLabelKeys.email),
              isRequired: widget.mode != AuthType.phone,
              hintText: context.translate(LanguageLabelKeys.enterEmail),
              keyboardType: TextInputType.emailAddress,
              readOnly: _isSocial,
              validator: (v) => v.validateEmail(
                context,
                required: widget.mode != AuthType.phone,
              ),
            ),
            AppSpacing.h16,
          ],

          if (widget.showPhone) ...[
            Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceS,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.phoneNumber),
                  isRequired: _isPhoneRequired,
                  style: context.tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AbsorbPointer(
                  absorbing: widget.phoneReadOnly,
                  child: Opacity(
                    opacity: widget.phoneReadOnly ? 0.6 : 1.0,
                    child: ApiCountryPhoneField(
                      controller: widget.phoneController,
                      selectedCountry: widget.selectedCountry,
                      isRequired: _isPhoneRequired,
                      hintText: context.translate(
                        LanguageLabelKeys.enterPhoneNumber,
                      ),
                      errorText: widget.phoneError,
                      onCountryChanged: widget.onCountryChanged,
                      onChanged: (number) => widget.onPhoneChanged(
                        number,
                        formatDialCode(widget.selectedCountry?.dialCode),
                      ),
                      validator: (v) => v.validateMobile(
                        context,
                        minLength:
                            widget.selectedCountry?.minMobileLength ?? 10,
                        required: _isPhoneRequired,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.h16,
          ],

          CountryDropdownField(
            selected: widget.selectedCountry,
            labelText: context.translate(LanguageLabelKeys.country),
            hintText: context.translate(LanguageLabelKeys.enterCountry),
            onChanged: widget.onCountryChanged,
          ),
          AppSpacing.h16,

          if (widget.showPassword) ...[
            AppTextField(
              controller: widget.passwordController,
              labelText: context.translate(LanguageLabelKeys.password),
              hintText: context.translate(LanguageLabelKeys.createPassword),
              isPassword: true,
              validator: (v) => v.validatePassword(context),
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
            AppSpacing.h16,
          ],

          if (widget.selectedCountry?.isReferalOn == 1)
            AppTextField(
              controller: widget.referralController,
              labelText: context.translate(LanguageLabelKeys.referralCode),
              hintText: context.translate(LanguageLabelKeys.enterReferralCode),
            ),
        ],
      ),
    );
  }
}
