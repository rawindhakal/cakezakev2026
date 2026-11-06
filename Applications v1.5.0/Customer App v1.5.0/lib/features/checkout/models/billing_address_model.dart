/// Billing address captured on checkout when it differs from the shipping
/// address — fields mirror the `billing_*` place-order request parameters.
class BillingAddressData {
  const BillingAddressData({
    required this.name,
    required this.mobile,
    required this.mobileCountryCode,
    required this.address,
    required this.city,
    required this.pincode,
    required this.country,
    required this.state,
    this.regionId,
  });

  final String name;

  /// National number only — [mobileCountryCode] carries the dial code
  /// (e.g. "+91"), same split [AddressData] uses.
  final String mobile;
  final String mobileCountryCode;
  final String address;
  final String city;
  final String pincode;
  final String country;

  /// State name — the region dropdown's picked name, or the free-text
  /// fallback typed when the country has no regions. Always sent as
  /// `billing_state`, regardless of which of the two it came from.
  final String state;

  /// Id of the state/region selected via the region dropdown. `null` when the
  /// country has no regions and [state] was typed into the free-text
  /// fallback field instead.
  final int? regionId;

  /// Dial code + national number combined, as sent in the `billing_mobile`
  /// place-order parameter (no separate `billing_country_code` param exists).
  String get fullMobile => '$mobileCountryCode$mobile';
}
