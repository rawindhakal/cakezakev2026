import 'package:customer/commons/widgets/app_select_field.dart';
import 'package:customer/commons/widgets/country_picker_sheet.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:flutter/material.dart';

/// Read-only "Country" select field — opens [showCountryPickerSheet] and
/// reports the chosen country back via [onChanged].
class CountryDropdownField extends StatelessWidget {
  final CountriesData? selected;
  final String labelText;
  final String hintText;
  final ValueChanged<CountriesData> onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;

  const CountryDropdownField({
    super.key,
    required this.selected,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    this.validator,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppSelectField(
      value: selected?.name,
      labelText: labelText,
      hintText: hintText,
      isRequired: isRequired,
      validator: validator,
      onTap: () async {
        final country = await showCountryPickerSheet(
          context,
          selected: selected,
        );
        if (country != null) onChanged(country);
      },
    );
  }
}
