import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

/// Name + primary/alternate mobile fields.
class ContactDetailsSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController altMobileCtrl;
  final CountriesData? selectedMobileCountry;
  final CountriesData? selectedAltMobileCountry;
  final ValueChanged<CountriesData> onMobileCountryChanged;
  final ValueChanged<CountriesData> onAltMobileCountryChanged;
  final ValueChanged<String> onMobileChanged;
  final ValueChanged<String> onAltMobileChanged;

  const ContactDetailsSection({
    super.key,
    required this.nameCtrl,
    required this.mobileCtrl,
    required this.altMobileCtrl,
    required this.selectedMobileCountry,
    required this.selectedAltMobileCountry,
    required this.onMobileCountryChanged,
    required this.onAltMobileCountryChanged,
    required this.onMobileChanged,
    required this.onAltMobileChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeConstants.spaceL,
      children: [
        AppTextField(
          controller: nameCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.fullName),
          hintText: context.translate(LanguageLabelKeys.enterFullName),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.nameRequired)
              : null,
        ),
        ApiCountryPhoneField(
          controller: mobileCtrl,
          selectedCountry: selectedMobileCountry,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.mobileNumber),
          hintText: context.translate(LanguageLabelKeys.enterMobileNumber),
          validator: (v) => (v == null || v.isEmpty)
              ? context.translate(LanguageLabelKeys.mobileRequired)
              : null,
          onCountryChanged: onMobileCountryChanged,
          onChanged: onMobileChanged,
        ),
        ApiCountryPhoneField(
          controller: altMobileCtrl,
          selectedCountry: selectedAltMobileCountry,
          labelText: context.translate(LanguageLabelKeys.alternateMobile),
          hintText: context.translate(LanguageLabelKeys.alternateMobile),
          validator: (v) => (v != null && v.isNotEmpty && v.length < 6)
              ? context.translate(LanguageLabelKeys.enterValidAlternateMobile)
              : null,
          onCountryChanged: onAltMobileCountryChanged,
          onChanged: onAltMobileChanged,
        ),
      ],
    );
  }
}
