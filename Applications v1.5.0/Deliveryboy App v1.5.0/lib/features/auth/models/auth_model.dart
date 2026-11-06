import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// Top-level response model for login/register/profile auth endpoints.
class AuthModel {
  int? status;
  String? message;
  AuthModelData? data;

  AuthModel({this.status, this.message, this.data});

  AuthModel.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    data = json['data'] != null ? AuthModelData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class AuthModelData {
  int? id;
  int? adminId;
  String? name;
  String? mobile;
  String? orderNote;
  String? address;
  int? bonusType;
  int? bonusPercentage;
  double? bonusMinAmount;
  double? bonusMaxAmount;
  double? balance;
  String? profile;
  String? drivingLicense;
  String? nationalIdentityCard;
  String? dob;
  String? bankAccountNumber;
  String? bankName;
  String? accountName;
  String? ifscCode;
  String? otherPaymentInformation;
  int? status;
  int? isAvailable;
  String? fcmId;
  String? pincodeId;
  int? cashReceived;
  String? createdAt;
  String? updatedAt;
  String? remark;
  int? pendingOrderCount;
  String? profileUrl;
  String? drivingLicenseUrl;
  String? nationalIdentityCardUrl;
  String? email;
  String? accessToken;
  int? countryId;
  String? countryCode;
  int? zoneId;
  int? returnBonusType;
  int? returnBonusPercentage;
  double? returnBonusMinAmount;
  double? returnBonusMaxAmount;

  AuthModelData({
    this.id,
    this.adminId,
    this.name,
    this.mobile,
    this.orderNote,
    this.address,
    this.bonusType,
    this.bonusPercentage,
    this.bonusMinAmount,
    this.bonusMaxAmount,
    this.balance,
    this.drivingLicense,
    this.nationalIdentityCard,
    this.dob,
    this.bankAccountNumber,
    this.bankName,
    this.accountName,
    this.ifscCode,
    this.otherPaymentInformation,
    this.status,
    this.isAvailable,
    this.fcmId,
    this.pincodeId,
    this.cashReceived,
    this.createdAt,
    this.updatedAt,
    this.remark,
    this.pendingOrderCount,
    this.profileUrl,
    this.drivingLicenseUrl,
    this.nationalIdentityCardUrl,
    this.email,
    this.accessToken,
    this.countryId,
    this.countryCode,
    this.zoneId,
    this.profile,
    this.returnBonusType,
    this.returnBonusPercentage,
    this.returnBonusMinAmount,
    this.returnBonusMaxAmount,
  });

  AuthModelData.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    adminId = toSafeIntOrNull(json['admin_id']);
    name = json['name']?.toString();
    mobile = json['mobile']?.toString();
    orderNote = json['order_note']?.toString();
    address = json['address']?.toString();
    bonusType = toSafeIntOrNull(json['bonus_type']);
    bonusPercentage = toSafeIntOrNull(json['bonus_percentage']);
    bonusMinAmount = toSafeDoubleOrNull(json['bonus_min_amount']);
    bonusMaxAmount = toSafeDoubleOrNull(json['bonus_max_amount']);
    balance = toSafeDoubleOrNull(json['balance']);
    drivingLicense = json['driving_license']?.toString();
    nationalIdentityCard = json['national_identity_card']?.toString();
    dob = json['dob']?.toString();
    bankAccountNumber = json['bank_account_number']?.toString() ?? "";
    bankName = json['bank_name']?.toString() ?? "";
    accountName = json['account_name']?.toString() ?? "";
    ifscCode = json['ifsc_code']?.toString() ?? "";
    otherPaymentInformation = json['other_payment_information']?.toString();
    status = toSafeIntOrNull(json['status']);
    isAvailable = toSafeIntOrNull(json['is_available']);
    fcmId = json['fcm_id']?.toString();
    pincodeId = json['pincode_id']?.toString();
    cashReceived = toSafeIntOrNull(json['cash_received']);
    createdAt = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    remark = json['remark']?.toString();
    pendingOrderCount = toSafeIntOrNull(json['pending_order_count']);
    profileUrl = json['profile_url']?.toString() ?? "";
    nationalIdentityCardUrl = json['national_identity_card_url']?.toString();
    drivingLicenseUrl = json['driving_license_url']?.toString();
    email = json['email']?.toString();
    accessToken = json['access_token']?.toString();
    countryId = toSafeIntOrNull(json['country_id']);
    countryCode = json['country_code']?.toString();
    zoneId = toSafeIntOrNull(json['zone_id']);
    profile = json['profile']?.toString();
    returnBonusType = toSafeIntOrNull(json['return_bonus_type']);
    returnBonusPercentage = toSafeIntOrNull(json['return_bonus_percentage']);
    returnBonusMinAmount = toSafeDoubleOrNull(json['return_bonus_min_amount']);
    returnBonusMaxAmount = toSafeDoubleOrNull(json['return_bonus_max_amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['admin_id'] = adminId;
    data['name'] = name;
    data['mobile'] = mobile;
    data['order_note'] = orderNote;
    data['address'] = address;
    data['bonus_type'] = bonusType;
    data['bonus_percentage'] = bonusPercentage;
    data['bonus_min_amount'] = bonusMinAmount;
    data['bonus_max_amount'] = bonusMaxAmount;
    data['balance'] = balance;
    data['driving_license'] = drivingLicense;
    data['national_identity_card'] = nationalIdentityCard;
    data['dob'] = dob;
    data['bank_account_number'] = bankAccountNumber;
    data['bank_name'] = bankName;
    data['account_name'] = accountName;
    data['ifsc_code'] = ifscCode;
    data['other_payment_information'] = otherPaymentInformation;
    data['status'] = status;
    data['is_available'] = isAvailable;
    data['fcm_id'] = fcmId;
    data['pincode_id'] = pincodeId;
    data['cash_received'] = cashReceived;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['remark'] = remark;
    data['pending_order_count'] = pendingOrderCount;
    data['profile_url'] = profileUrl;
    data['driving_license_url'] = drivingLicenseUrl;
    data['national_identity_card_url'] = nationalIdentityCardUrl;
    data['email'] = email;
    data['access_token'] = accessToken;
    if (countryId != null) data['country_id'] = countryId;
    if (countryCode != null) data['country_code'] = countryCode;
    if (zoneId != null) data['zone_id'] = zoneId;
    data['profile'] = profile;
    data['return_bonus_type'] = returnBonusType;
    data['return_bonus_percentage'] = returnBonusPercentage;
    data['return_bonus_min_amount'] = returnBonusMinAmount;
    data['return_bonus_max_amount'] = returnBonusMaxAmount;
    return data;
  }
}
