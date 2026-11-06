import 'package:customer/utils/json_parsers.dart';

class CountrySettings {
  int? status;
  String? message;
  CountrySettingsData? data;

  CountrySettings({this.status, this.message, this.data});

  CountrySettings.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']) ?? 0;
    message = parseString(json['message']) ?? "";
    data = json['data'] is Map<String, dynamic>
        ? CountrySettingsData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }
}

class CountrySettingsData {
  num? referralMinOrderAmount;
  num? referralCreditFirstOrder;
  num? referralCreditReferred;
  String? dateFormat;
  String? timeFormat;
  String? currency;
  String? currencyCode;
  int? decimalPoint;
  String? privacyPolicy;
  String? returnPolicy;
  String? shippingPolicy;
  String? cancellationPolicy;
  String? termsConditions;

  /// Buyer tax registration spec (GSTIN / VAT / TRN / ABN / EIN …) for the
  /// country resolved from the coordinates sent with the request — i.e. the
  /// BUYER's country, not the store's. `null` on an older server that does not
  /// return `buyer_tax_field` yet, which the UI treats exactly like
  /// `enabled: 0` (field hidden).
  BuyerTaxField? buyerTaxField;

  CountrySettingsData({
    this.referralMinOrderAmount,
    this.referralCreditFirstOrder,
    this.referralCreditReferred,
    this.dateFormat,
    this.timeFormat,
    this.currency,
    this.currencyCode,
    this.decimalPoint,
    this.privacyPolicy,
    this.returnPolicy,
    this.shippingPolicy,
    this.cancellationPolicy,
    this.termsConditions,
    this.buyerTaxField,
  });

  CountrySettingsData.fromJson(Map<String, dynamic> json) {
    referralMinOrderAmount = parseNum(json['referral_min_order_amount']);
    referralCreditFirstOrder = parseNum(json['referral_credit_first_order']);
    referralCreditReferred = parseNum(json['referral_credit_referred']);
    dateFormat = json['date_format']?.toString();
    timeFormat = json['time_format']?.toString();
    currency = json['currency']?.toString();
    currencyCode = json['currency_code']?.toString();
    decimalPoint = parseInt(json['decimal_point']);
    privacyPolicy = json['privacy_policy']?.toString();
    returnPolicy = json['return_policy']?.toString();
    shippingPolicy = json['shipping_policy']?.toString();
    cancellationPolicy = json['cancellation_policy']?.toString();
    termsConditions = json['terms_conditions']?.toString();
    buyerTaxField = json['buyer_tax_field'] is Map<String, dynamic>
        ? BuyerTaxField.fromJson(
            json['buyer_tax_field'] as Map<String, dynamic>,
          )
        : null;
  }
}

/// `buyer_tax_field` block of `GET customer/country_setting`.
///
/// Lets a business buyer put its own tax registration number on the ORDER
/// (typed on the order form, like the order note) so it travels onto the
/// invoice — without it on the face of the invoice a business buyer cannot
/// claim credit for the tax it paid. Never stored outside the order.
///
/// The field is OPTIONAL everywhere: most buyers are consumers with no number,
/// so the client must never make it required.
///
/// Admins control it per country (Countries → Country Details: a switch, the
/// field label and the format pattern). If a tester says the field vanished,
/// check that country's switch first.
class BuyerTaxField {
  /// `true` when the API sent `enabled: 1`. A country with no scheme of its
  /// own returns `enabled: 0` — the tax number / business name fields are
  /// then not shown at all and never sent (the server rejects a number sent
  /// for such a country with "A tax registration number is not collected for
  /// this country.").
  final bool enabled;

  /// The only word to print for the field — never hardcode "GST". India
  /// returns `GSTIN`, the UAE `TRN`, Australia `ABN`, the US `EIN`, the EU and
  /// the UK `VAT Number`.
  final String label;

  /// Client-side pre-validation pattern, e.g.
  /// `^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$` for GSTIN.
  /// `null` means anything the buyer types is accepted, with no format check
  /// of any kind.
  final String? regex;

  const BuyerTaxField({required this.enabled, required this.label, this.regex});

  /// Field hidden — used for a missing block, an `enabled: 0` country, or a
  /// failed `country_setting` call (the server still validates, so hiding
  /// the optional field can never block an order).
  static const disabled = BuyerTaxField(enabled: false, label: '');

  factory BuyerTaxField.fromJson(Map<String, dynamic> json) {
    final regex = parseString(json['regex']);
    return BuyerTaxField(
      enabled: parseInt(json['enabled']) == 1,
      label: parseString(json['label']) ?? '',
      regex: (regex == null || regex.isEmpty) ? null : regex,
    );
  }

  /// Normalises a typed value the same way the server stores it — uppercased
  /// with all whitespace stripped (`27 aapfu 0939 f1zv` → `27AAPFU0939F1ZV`).
  /// Used ONLY for the local regex check; the request still carries the value
  /// exactly as typed and the server does its own normalising.
  static String normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Local pre-validation of [value] against [regex].
  ///
  /// - Empty is always valid — clearing the field is a normal save.
  /// - `regex == null` accepts anything.
  /// - A pattern Dart cannot compile is treated as "no check" rather than
  ///   blocking the buyer; the server stays the source of truth.
  ///
  /// Passing this does NOT guarantee the server accepts it: India's GSTIN
  /// check digit (15th char, base-36 checksum) is verified server-side only,
  /// so a transposed pair still comes back as "Please enter a valid GSTIN."
  /// — the save/place-order error snackbar shows that server message as-is.
  bool isValid(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty || regex == null) return true;
    try {
      return RegExp(regex!).hasMatch(normalized);
    } on FormatException {
      return true;
    }
  }
}
