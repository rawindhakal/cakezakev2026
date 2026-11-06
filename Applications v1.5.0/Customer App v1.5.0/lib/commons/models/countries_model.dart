import 'package:customer/utils/json_parsers.dart';

class Countries {
  int? status;
  String? message;
  List<CountriesData>? data;
  int? total;

  Countries({this.status, this.message, this.data, this.total});

  Countries.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => CountriesData.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    total = parseInt(json['total']);
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
  int? isReferalOn;

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
    this.isReferalOn,
  });

  CountriesData.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    code = parseString(json['code']);
    currency = parseString(json['currency']);
    currencyCode = parseString(json['currency_code']);
    dialCode = parseString(json['dial_code']);
    logoUrl = parseString(json['logo_url']);
    isDefault = parseInt(json['is_default']) ?? 0;
    minMobileLength = parseInt(json['min_mobile_length']) ?? 10;
    maxMobileLength = parseInt(json['max_mobile_length']) ?? 10;
    isReferalOn = parseInt(json['is_referal_on']) ?? 0;
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
    data['is_referal_on'] = isReferalOn;
    return data;
  }
}
