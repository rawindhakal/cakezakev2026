import 'package:dio/dio.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// Handles all authentication and delivery-boy profile network calls.
class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// POST /login — returns full login response with token and delivery boy data.
  Future<AuthModel> login({
    required String email,
    required String password,
    String? fcmToken,
    String? platform,
    String? languageId,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        ApiParameters.email: email,
        ApiParameters.password: password,
        ApiParameters.type: "3",
        if (fcmToken != null && fcmToken.isNotEmpty)
          ApiParameters.fcmToken: fcmToken,
        if (platform != null && platform.isNotEmpty)
          ApiParameters.platform: platform,
        if (languageId != null && languageId.isNotEmpty)
          ApiParameters.languageId: languageId,
      },
    );
    return AuthModel.fromJson(response as Map<String, dynamic>);
  }

  /// POST /register — multipart upload supporting ID and licence images.
  Future<Map<String, dynamic>> register({
    required String name,
    required String mobile,
    required String password,
    required String confirmPassword,
    String? email,
    String? dob,
    String? profileImagePath,
    String? nationalIdImagePath,
    String? drivingLicenseImagePath,
    required String bonusType,
    String? bonusPercentage,
    String? bonusMinAmount,
    String? bonusMaxAmount,
    String? returnBonusType,
    String? returnBonusPercentage,
    String? returnBonusMinAmount,
    String? returnBonusMaxAmount,
    String? countryId,
    String? countryCode,
    String? zoneId,
  }) async {
    final Map<String, dynamic> fields = {
      ApiParameters.name: name,
      ApiParameters.mobile: mobile,
      ApiParameters.password: password,
      ApiParameters.confirmPassword: confirmPassword,
      ApiParameters.email: email,
      ApiParameters.dob: dob,
      ApiParameters.bonusType: bonusType,
      if (bonusType == "1" &&
          bonusPercentage != null &&
          bonusPercentage.isNotEmpty)
        ApiParameters.bonusPercentage: bonusPercentage,
      if (bonusType == "1" &&
          bonusMinAmount != null &&
          bonusMinAmount.isNotEmpty)
        ApiParameters.bonusMinAmount: bonusMinAmount,
      if (bonusType == "1" &&
          bonusMaxAmount != null &&
          bonusMaxAmount.isNotEmpty)
        ApiParameters.bonusMaxAmount: bonusMaxAmount,
      if (returnBonusType != null && returnBonusType.isNotEmpty)
        ApiParameters.returnBonusType: returnBonusType,
      if (returnBonusType == "1" &&
          returnBonusPercentage != null &&
          returnBonusPercentage.isNotEmpty)
        ApiParameters.returnBonusPercentage: returnBonusPercentage,
      if (returnBonusType == "1" &&
          returnBonusMinAmount != null &&
          returnBonusMinAmount.isNotEmpty)
        ApiParameters.returnBonusMinAmount: returnBonusMinAmount,
      if (returnBonusType == "1" &&
          returnBonusMaxAmount != null &&
          returnBonusMaxAmount.isNotEmpty)
        ApiParameters.returnBonusMaxAmount: returnBonusMaxAmount,
      if (countryId != null && countryId.isNotEmpty)
        ApiParameters.countryId: countryId,
      if (countryCode != null && countryCode.isNotEmpty)
        ApiParameters.countryCode: countryCode,
      if (zoneId != null && zoneId.isNotEmpty) ApiParameters.zoneId: zoneId,
    };

    if (profileImagePath != null) {
      fields[ApiParameters.profile] = await MultipartFile.fromFile(
        profileImagePath,
        filename: profileImagePath.split('/').last,
      );
    }

    if (nationalIdImagePath != null) {
      fields[ApiParameters.nationalIdentityCard] = await MultipartFile.fromFile(
        nationalIdImagePath,
        filename: nationalIdImagePath.split('/').last,
      );
    }
    if (drivingLicenseImagePath != null) {
      fields[ApiParameters.drivingLicense] = await MultipartFile.fromFile(
        drivingLicenseImagePath,
        filename: drivingLicenseImagePath.split('/').last,
      );
    }

    final response = await _apiClient.upload(
      ApiEndpoints.register,
      formData: FormData.fromMap(fields),
    );
    return response as Map<String, dynamic>;
  }

  /// POST /forgot_password — triggers OTP or reset link for the given email.
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final response = await _apiClient.post(
      ApiEndpoints.forgotPassword,
      data: {ApiParameters.email: email},
    );
    return response as Map<String, dynamic>;
  }

  /// POST /change_password — requires valid auth token in the Authorization header.
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.resetPassword,
      data: {
        ApiParameters.oldPassword: oldPassword,
        ApiParameters.newPassword: password,
        ApiParameters.confirmPassword: confirmPassword,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// GET /edit — fetch authenticated delivery boy profile.
  Future<AuthModel> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.editProfile);
    return AuthModel.fromJson(response as Map<String, dynamic>);
  }

  /// POST /add_fcm_token — adds FCM token if not available.
  Future<void> addFcmToken({
    required String fcmToken,
    required String platform,
  }) async {
    await _apiClient.post(
      ApiEndpoints.addFcmToken,
      data: {
        ApiParameters.fcmToken: fcmToken,
        ApiParameters.platform: platform,
      },
    );
  }

  /// POST /update_fcm_token — updates FCM token and active language on server.
  Future<void> updateFcmToken({
    required String fcmToken,
    required String languageId,
    required String platform,
  }) async {
    await _apiClient.post(
      ApiEndpoints.updateFcmToken,
      data: {
        ApiParameters.fcmToken: fcmToken,
        ApiParameters.languageId: languageId,
        ApiParameters.platform: platform,
      },
    );
  }

  /// POST /logout — invalidates the server session token.
  Future<void> logout() async {
    await _apiClient.post(
      ApiEndpoints.logout,
      data: {ApiParameters.fcmToken: AuthHiveBox.instance.fcmToken},
    );
  }

  /// GET /get_delivery_boy_status — returns account status (4 = blocked) and remark.
  ///
  /// `status` is parsed leniently: the backend sends it as a bare int on some
  /// endpoints and a quoted string on others, and a hard `as int` cast on the
  /// string form threw — which the cubit swallowed into a generic error state,
  /// so a *blocked* account silently rendered "something went wrong" instead
  /// of the blocked dialog.
  Future<({int status, String? remark})> getDeliveryBoyStatus() async {
    final response = await _apiClient.get(ApiEndpoints.getDeliveryBoyStatus);
    final data = (response as Map<String, dynamic>)['data'];
    final status = data is Map ? toSafeIntOrNull(data['status']) : null;
    if (status == null) {
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.invalidResponseFormat,
        ),
      );
    }
    return (status: status, remark: (data as Map)['remark']?.toString());
  }

  /// POST /update_delivery_boy_status — sets online (1) / offline (3) availability.
  Future<void> updateDeliveryBoyStatus({required int status}) async {
    await _apiClient.post(
      ApiEndpoints.updateDeliveryBoyStatus,
      data: {ApiParameters.status: status},
    );
  }

  /// POST /delete_account — permanently deletes the delivery boy account.
  Future<void> deleteAccount() async {
    await _apiClient.post(ApiEndpoints.deleteDeliveryBoyAccount);
  }

  /// POST /update — multipart upload to update delivery boy profile fields.
  Future<AuthModel> updateProfile({
    required String name,
    required String mobile,
    String? email,
    String? address,
    String? dob,
    String? bankAccountNumber,
    String? bankName,
    String? accountName,
    String? ifscCode,
    String? bonusType,
    String? bonusPercentage,
    String? bonusMinAmount,
    String? bonusMaxAmount,
    String? returnBonusType,
    String? returnBonusPercentage,
    String? returnBonusMinAmount,
    String? returnBonusMaxAmount,
    String? profileImagePath,
    String? nationalIdImagePath,
    String? drivingLicenseImagePath,
    String? countryId,
    String? zoneId,
  }) async {
    final Map<String, dynamic> fields = {
      ApiParameters.name: name,
      ApiParameters.mobile: mobile,
      if (email != null && email.isNotEmpty) ApiParameters.email: email,
      if (address != null && address.isNotEmpty) ApiParameters.address: address,
      if (dob != null && dob.isNotEmpty) ApiParameters.dob: dob,
      if (bankAccountNumber != null && bankAccountNumber.isNotEmpty)
        ApiParameters.bankAccountNumber: bankAccountNumber,
      if (bankName != null && bankName.isNotEmpty)
        ApiParameters.bankName: bankName,
      if (accountName != null && accountName.isNotEmpty)
        ApiParameters.accountName: accountName,
      if (ifscCode != null && ifscCode.isNotEmpty)
        ApiParameters.ifscCode: ifscCode,
      if (bonusType != null && bonusType.isNotEmpty)
        ApiParameters.bonusType: bonusType,
      if (bonusType == "1" &&
          bonusPercentage != null &&
          bonusPercentage.isNotEmpty)
        ApiParameters.bonusPercentage: bonusPercentage,
      if (bonusType == "1" &&
          bonusMinAmount != null &&
          bonusMinAmount.isNotEmpty)
        ApiParameters.bonusMinAmount: bonusMinAmount,
      if (bonusType == "1" &&
          bonusMaxAmount != null &&
          bonusMaxAmount.isNotEmpty)
        ApiParameters.bonusMaxAmount: bonusMaxAmount,
      if (returnBonusType != null && returnBonusType.isNotEmpty)
        ApiParameters.returnBonusType: returnBonusType,
      if (returnBonusType == "1" &&
          returnBonusPercentage != null &&
          returnBonusPercentage.isNotEmpty)
        ApiParameters.returnBonusPercentage: returnBonusPercentage,
      if (returnBonusType == "1" &&
          returnBonusMinAmount != null &&
          returnBonusMinAmount.isNotEmpty)
        ApiParameters.returnBonusMinAmount: returnBonusMinAmount,
      if (returnBonusType == "1" &&
          returnBonusMaxAmount != null &&
          returnBonusMaxAmount.isNotEmpty)
        ApiParameters.returnBonusMaxAmount: returnBonusMaxAmount,
      if (countryId != null && countryId.isNotEmpty)
        ApiParameters.countryId: countryId,
      if (zoneId != null && zoneId.isNotEmpty) ApiParameters.zoneId: zoneId,
    };

    if (profileImagePath != null) {
      fields[ApiParameters.profile] = await MultipartFile.fromFile(
        profileImagePath,
        filename: profileImagePath.split('/').last,
      );
    }

    if (nationalIdImagePath != null) {
      fields[ApiParameters.nationalIdentityCard] = await MultipartFile.fromFile(
        nationalIdImagePath,
        filename: nationalIdImagePath.split('/').last,
      );
    }

    if (drivingLicenseImagePath != null) {
      fields[ApiParameters.drivingLicense] = await MultipartFile.fromFile(
        drivingLicenseImagePath,
        filename: drivingLicenseImagePath.split('/').last,
      );
    }

    final response = await _apiClient.upload(
      ApiEndpoints.update,
      formData: FormData.fromMap(fields),
    );
    return AuthModel.fromJson(response as Map<String, dynamic>);
  }
}
