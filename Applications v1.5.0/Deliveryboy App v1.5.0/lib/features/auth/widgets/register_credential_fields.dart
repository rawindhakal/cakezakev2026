import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/country_dropdown_field.dart';
import 'package:deliveryboy/commons/widgets/country_phone_field.dart';
import 'package:deliveryboy/commons/widgets/password_requirements_checklist.dart';
import 'package:deliveryboy/commons/widgets/zone_dropdown_field.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/password_policy.dart';
import 'package:flutter/material.dart';
import '../../../commons/widgets/app_text_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../utils/input_validators.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Credential input fields (name, email, mobile, password, etc.) for registration.
class RegisterCredentialFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController dobController;
  final TextEditingController mobileController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final CountriesData? selectedCountry;
  final ValueChanged<CountriesData> onCountryChanged;
  final ZonesData? selectedZone;
  final ValueChanged<ZonesData> onZoneChanged;
  final String? Function(String?)? zoneValidator;
  final VoidCallback onPickDob;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;
  final bool obscureConfirm;
  final VoidCallback onToggleObscureConfirm;

  const RegisterCredentialFields({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.dobController,
    required this.mobileController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.selectedZone,
    required this.onZoneChanged,
    this.zoneValidator,
    required this.onPickDob,
    required this.obscurePassword,
    required this.onToggleObscurePassword,
    required this.obscureConfirm,
    required this.onToggleObscureConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        _label(
          context,
          context.translate(LanguageLabelKeys.fullName),
          isRequired: true,
        ),
        AppSpacing.h8,
        AppTextField(
          controller: nameController,
          hintText: context.translate(LanguageLabelKeys.enterFullName),
          textCapitalization: TextCapitalization.words,
          validator: (v) => v.validateRequired(
            context,
            context.translate(LanguageLabelKeys.fullName),
          ),
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.email),
          isRequired: true,
        ),
        AppSpacing.h8,
        AppTextField(
          controller: emailController,
          hintText: context.translate(LanguageLabelKeys.enterEmail),
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v.validateEmail(context),
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.dateOfBirth),
          isRequired: true,
        ),
        AppSpacing.h8,
        AppTextField(
          controller: dobController,
          hintText: context.translate(LanguageLabelKeys.enterDob),
          readOnly: true,
          onTap: onPickDob,
          suffixIcon: AppSvgIcon(
            AssetsConstants.dateIcon,
            size: ThemeConstants.iconS,
            color: context.cs.onSurfaceVariant,
            fit: BoxFit.scaleDown,
          ),
          validator: (v) => v.validateRequired(
            context,
            context.translate(LanguageLabelKeys.dateOfBirth),
          ),
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.country),
          isRequired: true,
        ),
        AppSpacing.h8,
        CountryDropdownField(
          selected: selectedCountry,
          labelText: '',
          hintText: context.translate(LanguageLabelKeys.selectCountry),
          onChanged: onCountryChanged,
          validator: (_) => selectedCountry == null
              ? context
                    .translate(LanguageLabelKeys.fieldRequired)
                    .replaceAll(
                      '{field}',
                      context.translate(LanguageLabelKeys.country),
                    )
              : null,
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.zone),
          isRequired: true,
        ),
        AppSpacing.h8,
        ZoneDropdownField(
          selected: selectedZone,
          labelText: '',
          hintText: context.translate(LanguageLabelKeys.selectZone),
          onChanged: onZoneChanged,
          validator: zoneValidator,
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.mobileNumber),
          isRequired: true,
        ),
        AppSpacing.h8,
        ApiCountryPhoneField(
          controller: mobileController,
          selectedCountry: selectedCountry,
          onCountryChanged: onCountryChanged,
          hintText: context.translate(LanguageLabelKeys.mobileNumber),
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.password),
          isRequired: true,
        ),
        AppSpacing.h8,
        AppTextField(
          controller: passwordController,
          hintText: context.translate(LanguageLabelKeys.enterPassword),
          obscureText: obscurePassword,
          suffixIcon: IconButton(
            icon: AppSvgIcon(
              obscurePassword
                  ? AssetsConstants.passwordHideIcon
                  : AssetsConstants.passwordVisibleIcon,
              color: context.cs.onSurfaceVariant,
              size: ThemeConstants.iconM,
            ),
            onPressed: onToggleObscurePassword,
          ),
          validator: (v) => v.validatePassword(context),
        ),
        AppSpacing.h8,
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: passwordController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : PasswordRequirementsChecklist(
                  password: value.text,
                  policy: PasswordPolicy.fromSettings(),
                ),
        ),
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.confirmPassword),
          isRequired: true,
        ),
        AppSpacing.h8,
        AppTextField(
          controller: confirmPasswordController,
          hintText: context.translate(LanguageLabelKeys.reEnterPassword),
          obscureText: obscureConfirm,
          suffixIcon: IconButton(
            icon: AppSvgIcon(
              obscureConfirm
                  ? AssetsConstants.passwordHideIcon
                  : AssetsConstants.passwordVisibleIcon,
              color: context.cs.onSurfaceVariant,
              size: ThemeConstants.iconM,
            ),
            onPressed: onToggleObscureConfirm,
          ),
          validator: (v) =>
              v.validateConfirmPassword(context, passwordController.text),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text, {bool isRequired = false}) {
    return AppText(
      text,
      isRequired: isRequired,
      style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface),
    );
  }
}
