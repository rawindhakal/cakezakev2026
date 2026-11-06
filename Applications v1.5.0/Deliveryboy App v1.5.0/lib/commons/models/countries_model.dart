import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// API response envelope wrapping the list of [CountriesData].
class Countries {
  int? status;
  String? message;
  List<CountriesData>? data;
  int? total;

  Countries({this.status, this.message, this.data, this.total});

  Countries.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    if (json['data'] != null) {
      data = <CountriesData>[];
      json['data'].forEach((v) {
        data!.add(CountriesData.fromJson(v));
      });
    }
    total = toSafeIntOrNull(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['total'] = total;
    return data;
  }
}

/// A single country entry with dial code and currency info, used by phone/country pickers.
class CountriesData {
  int? id;
  String? name;
  String? code;
  String? currency;
  String? currencyCode;
  String? dialCode;
  String? logoUrl;
  int? isDefault;
  int? minMobileLength;
  int? maxMobileLength;

  CountriesData({
    this.id,
    this.name,
    this.code,
    this.currency,
    this.currencyCode,
    this.dialCode,
    this.logoUrl,
    this.isDefault,
    this.minMobileLength,
    this.maxMobileLength,
  });

  CountriesData.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    name = json['name']?.toString();
    code = json['code']?.toString();
    currency = json['currency']?.toString();
    currencyCode = json['currency_code']?.toString();
    dialCode = json['dial_code']?.toString();
    logoUrl = json['logo_url']?.toString();
    isDefault = toSafeInt(json['is_default'], 0);
    minMobileLength = toSafeInt(json['min_mobile_length'], 10);
    maxMobileLength = toSafeInt(json['max_mobile_length'], 10);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['code'] = code;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['dial_code'] = dialCode;
    data['logo_url'] = logoUrl;
    data['is_default'] = isDefault;
    data['min_mobile_length'] = minMobileLength;
    data['max_mobile_length'] = maxMobileLength;
    return data;
  }
}
