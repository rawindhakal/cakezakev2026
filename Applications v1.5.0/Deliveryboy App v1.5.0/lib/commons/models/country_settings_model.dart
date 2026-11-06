import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// API response envelope wrapping [CountrySettingsData].
class CountrySettings {
  int? status;
  String? message;
  CountrySettingsData? data;

  CountrySettings({this.status, this.message, this.data});

  CountrySettings.fromJson(Map<String, dynamic> json) {
    status = toSafeInt(json['status'], 0);
    message = json['message']?.toString() ?? "";
    data = json['data'] != null
        ? CountrySettingsData.fromJson(json['data'])
        : null;
  }
}

/// Per-country settings: date/time format, currency, and legal document text.
class CountrySettingsData {
  String? dateFormat;
  String? timeFormat;
  String? privacyPolicy;
  String? termsConditions;
  String? currency;

  CountrySettingsData({
    this.dateFormat,
    this.timeFormat,
    this.privacyPolicy,
    this.termsConditions,
    this.currency,
  });

  CountrySettingsData.fromJson(Map<String, dynamic> json) {
    dateFormat = json['date_format']?.toString();
    timeFormat = json['time_format']?.toString();
    privacyPolicy = json['privacy_policy_delivery_boy']?.toString();
    termsConditions = json['terms_conditions_delivery_boy']?.toString();
    currency = (json['currency'] ?? json['currency_symbol'])?.toString();
  }
}
