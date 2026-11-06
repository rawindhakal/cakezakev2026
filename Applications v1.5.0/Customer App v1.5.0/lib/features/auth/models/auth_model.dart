import 'package:customer/utils/json_parsers.dart';

class AuthModel {
  int? status;
  String? message;
  String? statusCode;
  AuthModelData? data;

  AuthModel({this.status, this.message, this.statusCode, this.data});

  AuthModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']) ?? 0;
    message = parseString(json['message']) ?? "";
    statusCode = parseString(json['status_code']) ?? "";
    data = json['data'] is Map<String, dynamic>
        ? AuthModelData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['status_code'] = statusCode;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class AuthModelData {
  int? id;
  String? name;
  String? email;
  String? countryCode;
  int? countryId;
  String? mobile;
  String? profile;
  double? balance;
  String? referralCode;
  String? type;
  String? accessToken;

  AuthModelData({
    this.id,
    this.name,
    this.email,
    this.countryCode,
    this.countryId,
    this.mobile,
    this.profile,
    this.balance,
    this.referralCode,
    this.type,
    this.accessToken,
  });

  AuthModelData.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']) ?? 0;
    name = parseString(json['name']) ?? "";
    email = parseString(json['email']) ?? "";
    countryCode = parseString(json['country_code']) ?? "";
    countryId = parseInt(json['country_id']);
    mobile = parseString(json['mobile']) ?? "";
    profile = parseString(json['profile']) ?? "";
    balance = parseDouble(json['balance']);
    referralCode = parseString(json['referral_code']) ?? "";
    type = parseString(json['type']) ?? "";
    accessToken = parseString(json['access_token']) ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['email'] = email;
    data['country_code'] = countryCode;
    data['country_id'] = countryId;
    data['mobile'] = mobile;
    data['profile'] = profile;
    data['balance'] = balance;
    data['referral_code'] = referralCode;
    data['type'] = type;
    data['access_token'] = accessToken;
    return data;
  }
}
