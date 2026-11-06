import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/commons/models/country_settings_model.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

/// Buyer tax number (GSTIN / VAT / TRN …) + business name inputs for the
/// checkout order form → `buyer_tax_number` / `buyer_business_name` on
/// place_order. Never part of an address (address add/update neither take
/// nor return them).
///
/// Callers render this ONLY when [field] is enabled, under a
/// "Business details" heading so a consumer skips straight past.
/// Both inputs are optional — never mark them required: empty is always valid
/// and clearing them is a normal save.
class BuyerTaxFields extends StatelessWidget {
  final BuyerTaxField field;
  final TextEditingController businessNameCtrl;
  final TextEditingController taxNumberCtrl;

  const BuyerTaxFields({
    super.key,
    required this.field,
    required this.businessNameCtrl,
    required this.taxNumberCtrl,
  });

  /// API column limits — `business_name` is varchar(191), `tax_number` 64.
  static const int businessNameMaxLength = 191;
  static const int taxNumberMaxLength = 64;

  @override
  Widget build(BuildContext context) {
    // The api label is the only word printed for the number — "GSTIN",
    // "TRN", "ABN", "EIN", "VAT Number"… never a hardcoded "GST".
    final label = field.label;
    return Column(
      spacing: ThemeConstants.spaceL,
      children: [
        AppTextField(
          controller: businessNameCtrl,
          labelText: context.translate(LanguageLabelKeys.businessName),
          hintText: context.translate(LanguageLabelKeys.enterBusinessName),
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            LengthLimitingTextInputFormatter(businessNameMaxLength),
          ],
        ),
        AppTextField(
          controller: taxNumberCtrl,
          labelText: label,
          hintText: context
              .translate(LanguageLabelKeys.enterBuyerTaxNumber)
              .replaceAll('{label}', label),
          // Capitalisation is a typing convenience only — the value is still
          // sent as typed and the server uppercases / strips spaces itself.
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            LengthLimitingTextInputFormatter(taxNumberMaxLength),
          ],
          // Local pre-check against `buyer_tax_field.regex` (null regex = no
          // check). Same wording as the server's error so both read alike;
          // the server may still refuse a pattern-valid GSTIN on its check
          // digit, and that message surfaces through the save/place-order
          // error snackbar.
          validator: (v) => field.isValid(v ?? '')
              ? null
              : context
                    .translate(LanguageLabelKeys.pleaseEnterValidBuyerTaxNumber)
                    .replaceAll('{label}', label),
        ),
      ],
    );
  }
}
