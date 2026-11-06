import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

/// Address, landmark, area and city/pincode/state/country fields.
class AddressDetailsSection extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController pincodeCtrl;

  /// State selector — either the [RegionDropdownField] (country has regions)
  /// or the free-text manual fallback, built by the parent so it can switch
  /// between the two based on the regions api response.
  final Widget stateField;

  /// Country selector — the [CountryDropdownField], built by the parent so
  /// selecting a country can drive the region fetch.
  final Widget countryField;

  /// Snapshotted once by the parent at init — whether these fields already
  /// had a value (from the saved address / map geocode) before the user
  /// touched anything. Deciding this from live controller text instead would
  /// re-lock a field the moment the user finishes typing into it.
  final bool cityPrefilled;
  final bool pincodePrefilled;

  const AddressDetailsSection({
    super.key,
    required this.addressCtrl,
    required this.landmarkCtrl,
    required this.areaCtrl,
    required this.cityCtrl,
    required this.pincodeCtrl,
    required this.stateField,
    required this.countryField,
    required this.cityPrefilled,
    required this.pincodePrefilled,
  });

  @override
  Widget build(BuildContext context) {
    // Fields already filled from the map pick are hidden entirely — only
    // fields missing from the geocoding result stay open for manual entry.
    final showCity = !cityPrefilled;
    final showPincode = !pincodePrefilled;

    final cityField = AppTextField(
      controller: cityCtrl,
      isRequired: true,
      labelText: context.translate(LanguageLabelKeys.city),
      hintText: context.translate(LanguageLabelKeys.enterCity),
      textCapitalization: TextCapitalization.words,
      validator: (v) => (v == null || v.trim().isEmpty)
          ? context.translate(LanguageLabelKeys.required)
          : null,
    );

    final pincodeField = AppTextField(
      controller: pincodeCtrl,
      isRequired: true,
      labelText: context.translate(LanguageLabelKeys.pincode),
      hintText: context.translate(LanguageLabelKeys.enterPincode),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) => (v == null || v.trim().isEmpty)
          ? context.translate(LanguageLabelKeys.required)
          : null,
    );

    return Column(
      spacing: ThemeConstants.spaceL,
      children: [
        AppTextField(
          controller: addressCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.address),
          hintText: context.translate(LanguageLabelKeys.enterFullAddress),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.addressRequired)
              : null,
        ),
        AppTextField(
          controller: landmarkCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.landmark),
          hintText: context.translate(LanguageLabelKeys.nearbyLandmark),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.landmarkRequired)
              : null,
        ),
        AppTextField(
          controller: areaCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.areaLocality),
          hintText: context.translate(LanguageLabelKeys.enterAreaOrLocality),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.areaRequired)
              : null,
        ),
        if (showCity || showPincode)
          Row(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceM,
            children: [
              if (showCity) Expanded(child: cityField),
              if (showPincode) Expanded(child: pincodeField),
            ],
          ),
        Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceM,
          children: [
            Expanded(child: countryField),
            Expanded(child: stateField),
          ],
        ),
      ],
    );
  }
}
