import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/country_picker_sheet.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/commons/widgets/app_text.dart';

/// Normalizes a raw api dial code (with or without a leading "+") to the
/// "+xx" format the rest of the app sends as `country_code`.
String formatDialCode(String? dialCode) {
  final clean = (dialCode ?? '').trim();
  if (clean.isEmpty) return '';
  return '+${clean.replaceAll('+', '')}';
}

/// Finds the country in [countries] matching [dialCode] (with or without a
/// leading "+"). Used to preselect the default country for phone/country
/// fields once the api list loads.
CountriesData? findCountryByDialCode(
  List<CountriesData> countries,
  String dialCode,
) {
  final clean = dialCode.replaceAll('+', '');
  if (clean.isEmpty) return null;
  final match = countries
      .where((c) => (c.dialCode ?? '').replaceAll('+', '') == clean)
      .toList();
  return match.isNotEmpty ? match.first : null;
}

/// Returns the country flagged `is_default = 1` by the api, falling back to
/// [AppConfig.defaultCountry] when no country is flagged (or the list is empty).
CountriesData? findDefaultCountry(List<CountriesData> countries) {
  final flagged = countries.where((c) => c.isDefault == 1).toList();
  if (flagged.isNotEmpty) return flagged.first;
  return findCountryByDialCode(
    countries,
    AppConfig.defaultCountry.dialCode ?? '',
  );
}

/// Phone number field whose country/dial-code prefix is driven by the
/// countries api (flag + dial code) instead of the static package list.
class ApiCountryPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final CountriesData? selectedCountry;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final bool readOnly;
  final bool isRequired;
  final ValueChanged<CountriesData> onCountryChanged;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const ApiCountryPhoneField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.hintText,
    this.labelText,
    this.errorText,
    this.readOnly = false,
    this.isRequired = false,
    this.onChanged,
    this.validator,
  });

  Future<void> _pickCountry(BuildContext context) async {
    final country = await showCountryPickerSheet(
      context,
      selected: selectedCountry,
      showDialCode: true,
    );
    if (country != null) onCountryChanged(country);
  }

  @override
  Widget build(BuildContext context) {
    final maxLen = selectedCountry?.maxMobileLength;
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: ThemeConstants.spaceS,
      children: [
        AppTextField(
          controller: controller,
          labelText: labelText,
          isRequired: isRequired,
          hintText:
              hintText ?? context.translate(LanguageLabelKeys.mobileNumber),
          readOnly: readOnly,
          keyboardType: TextInputType.phone,
          maxLength: maxLen,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            if (maxLen != null) LengthLimitingTextInputFormatter(maxLen),
          ],
          onChanged: onChanged,
          validator:
              validator ??
              (v) => v.validateMobile(
                context,
                minLength: selectedCountry?.minMobileLength ?? 10,
              ),
          // Own semantics node (container) with its content excluded: the
          // flag/dial code swap otherwise feeds InputDecorator's prefix
          // sibling-merge group, which on Flutter 3.47 can make a semantics
          // node its own child ('!newChildren.any(child == this)' assertion).
          prefixIcon: Semantics(
            container: true,
            button: !readOnly,
            label: formatDialCode(selectedCountry?.dialCode),
            onTap: readOnly ? null : () => _pickCountry(context),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: readOnly ? null : () => _pickCountry(context),
              excludeFromSemantics: true,
              child: _CountryDialCodeChip(country: selectedCountry),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
        if ((errorText ?? '').isNotEmpty) ...[
          AppText(
            errorText!,
            style: context.tt.bodySmall?.copyWith(color: context.cs.error),
          ),
        ],
      ],
    );
  }
}

class _CountryDialCodeChip extends StatelessWidget {
  final CountriesData? country;
  const _CountryDialCodeChip({required this.country});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: ThemeConstants.spaceM,
        end: ThemeConstants.spaceXS,
      ),
      child: Row(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceXS,
        children: [
          AppNetworkImage(
            url: country?.logoUrl ?? '',
            width: ThemeConstants.iconM,
            height: ThemeConstants.iconM,
            errorWidget: AppSvgIcon(
              AssetsConstants.flagIcon,
              size: ThemeConstants.iconXS,
              color: context.cs.onSurfaceVariant,
            ),
          ),
          AppText(
            formatDialCode(country?.dialCode),
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurface),
          ),
          AppSvgIcon(
            AssetsConstants.arrowDownIcon,
            size: ThemeConstants.iconS,
            color: context.cs.onSurfaceVariant,
          ),
          Container(width: 1, height: 22, color: context.cs.outline),
        ],
      ),
    );
  }
}
