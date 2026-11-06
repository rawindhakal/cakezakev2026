import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/country_picker_sheet.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

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

  /// When true, the country picker is disabled but the text field remains
  /// editable. Use in profile edit where mobile can change but country cannot.
  final bool countryReadOnly;
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
    this.countryReadOnly = false,
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
      children: [
        AppTextField(
          controller: controller,
          labelText: labelText,
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
          prefixIcon: IntrinsicWidth(
            child: GestureDetector(
              onTap: (readOnly || countryReadOnly)
                  ? null
                  : () => _pickCountry(context),
              child: _CountryDialCodeChip(
                country: selectedCountry,
                disabled: readOnly || countryReadOnly,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
        if ((errorText ?? '').isNotEmpty) ...[
          AppSpacing.h6,
          AppText(
            errorText!,
            style: context.tt.bodySmall?.copyWith(color: context.cs.error),
          ),
        ],
      ],
    );
  }
}

class _CountryDialCodeChip extends StatefulWidget {
  final CountriesData? country;
  final bool disabled;
  const _CountryDialCodeChip({required this.country, this.disabled = false});

  @override
  State<_CountryDialCodeChip> createState() => _CountryDialCodeChipState();
}

/// Loads the flag image outside the TextField's own layout pass — resolving
/// a network image while it's still the prefixIcon can make the field's
/// InputDecorator re-enter layout mid-pass, which hangs release builds (no
/// exception thrown, since the assert that would catch it is stripped in
/// release). Precache first and only swap in the real image once it's ready.
class _CountryDialCodeChipState extends State<_CountryDialCodeChip> {
  bool _imageReady = false;
  String? _precachedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePrecache();
  }

  @override
  void didUpdateWidget(covariant _CountryDialCodeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.country?.logoUrl != widget.country?.logoUrl) {
      _imageReady = false;
      _maybePrecache();
    }
  }

  void _maybePrecache() {
    final url = widget.country?.logoUrl;
    if (url == null || url.isEmpty || url == _precachedUrl) return;
    _precachedUrl = url;
    precacheImage(AppNetworkImage.provider(url), context)
        .then((_) {
          if (mounted && _precachedUrl == url) {
            setState(() => _imageReady = true);
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.country?.logoUrl;
    final showImage = _imageReady && url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      child: Row(
        mainAxisSize: .min,
        children: [
          SizedBox(
            width: context.screenWidth * 0.053,
            height: context.screenWidth * 0.053,
            child: showImage
                ? AppNetworkImage(
                    url: url,
                    fit: .cover,
                    errorWidget:  AppSvgIcon(
                      AssetsConstants.flagIcon,
                      size: ThemeConstants.iconM,
                      color: context.cs.onSurfaceVariant,
                    ),
                  )
                : AppSvgIcon(
                    AssetsConstants.flagIcon,
                    size: ThemeConstants.iconM,
                    color: context.cs.onSurfaceVariant,
                  ),
          ),
          AppSpacing.w6,
          AppText(
            formatDialCode(widget.country?.dialCode),
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurface),
          ),
          AppSpacing.w4,
          if (!widget.disabled)
            AppSvgIcon(
              AssetsConstants.arrowDownIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurfaceVariant,
            ),
          AppSpacing.w6,
          Container(
            width: 1,
            height: context.screenHeight * 0.027,
            color: context.cs.outline,
          ),
        ],
      ),
    );
  }
}
