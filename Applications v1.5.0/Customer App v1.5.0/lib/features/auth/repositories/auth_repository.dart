import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:dio/dio.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/auth/models/auth_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  AuthRepository({ApiClient? apiClient, FirebaseAuth? firebaseAuth})
    : _apiClient = apiClient ?? ApiClient(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Every login/OTP flow calls this right before sending the token to the
  /// backend — persisting it here too keeps AuthHiveBox.fcmToken in sync
  /// without having to touch each of those call sites individually.
  Future<String?> getFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await AuthHiveBox.instance.setFcmToken(token);
    return token;
  }

  /// POST /login — returns full login response with token and delivery boy data.
  Future<AuthModel> loginWithPhoneOtp({
    required String id,
    required String type,
    required String phoneAuthType,
    String? languageId,
  }) async {
    try {
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          ApiParameters.id: id,
          ApiParameters.type: type,
          ApiParameters.phoneAuthType: phoneAuthType,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
          if (languageId != null && languageId.isNotEmpty)
            ApiParameters.languageId: languageId,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /login — returns full login response with token and delivery boy data.
  Future<AuthModel> loginWithPhonePassword({
    required String id,
    required String password,
    required String type,
    required String phoneAuthType,
    required String countryCode,
    String? languageId,
  }) async {
    try {
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          ApiParameters.id: id,
          ApiParameters.countryCode: countryCode,
          ApiParameters.password: password,
          ApiParameters.type: type,
          ApiParameters.phoneAuthType: phoneAuthType,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
          if (languageId != null && languageId.isNotEmpty)
            ApiParameters.languageId: languageId,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /login — Google social login. If [preAuthEmail] is provided, skips Firebase and posts directly.
  Future<AuthModel> loginWithGoogle({
    required String type,
    String? languageId,
    String? preAuthEmail,
  }) async {
    try {
      String googleEmail;
      if (preAuthEmail != null) {
        googleEmail = preAuthEmail;
      } else {
        final credential = await signInWithGoogleFirebase();
        final firebaseUser = credential.user;
        if (firebaseUser == null) {
          throw ApiException(
            message: LocalizationService.instance.translate(
              LanguageLabelKeys.googleAuthFailed,
            ),
          );
        }
        googleEmail = firebaseUser.email ?? '';
      }
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          ApiParameters.id: googleEmail,
          ApiParameters.type: type,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
          if (languageId != null && languageId.isNotEmpty)
            ApiParameters.languageId: languageId,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /login — Apple social login. If [preAuthEmail] is provided, skips Firebase and posts directly.
  Future<AuthModel> loginWithApple({
    required String type,
    String? languageId,
    String? preAuthEmail,
  }) async {
    try {
      String appleEmail;
      if (preAuthEmail != null) {
        appleEmail = preAuthEmail;
      } else {
        final credential = await signInWithAppleFirebase();
        final firebaseUser = credential.user;
        if (firebaseUser == null) {
          throw ApiException(
            message: LocalizationService.instance.translate(
              LanguageLabelKeys.appleAuthFailed,
            ),
          );
        }
        appleEmail = firebaseUser.email ?? '';
      }
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          ApiParameters.id: appleEmail,
          ApiParameters.type: type,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
          if (languageId != null && languageId.isNotEmpty)
            ApiParameters.languageId: languageId,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Firebase Google sign in flow.
  Future<UserCredential> signInWithGoogleFirebase() async {
    try {
      await GoogleSignIn.instance.initialize();
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email'],
      );
      final idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        throw ApiException(
          message: 'Unable to obtain Google authentication token.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const ApiException(message: '', isCancelled: true);
      }
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.googleAuthFailed,
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw ApiException(message: e.message ?? e.code);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Firebase Apple sign in flow.
  Future<UserCredential> signInWithAppleFirebase({
    String? clientId,
    String? redirectUri,
  }) async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: clientId != null && redirectUri != null
            ? WebAuthenticationOptions(
                clientId: clientId,
                redirectUri: Uri.parse(redirectUri),
              )
            : null,
      );

      if (appleCredential.identityToken == null) {
        throw ApiException(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.appleIdentityTokenFailed,
          ),
        );
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const ApiException(message: '', isCancelled: true);
      }
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.somethingWentWrong,
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw ApiException(message: e.message ?? e.code);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXZYabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Firebase phone OTP — sends OTP to phone number.
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required String countryCode,
  }) async {
    final completer = Completer<void>();
    try {
      _firebaseAuth.verifyPhoneNumber(
        phoneNumber: "$countryCode$phoneNumber",
        verificationCompleted: (PhoneAuthCredential credential) {
          if (!completer.isCompleted) completer.complete();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(ApiException(message: e.message ?? e.code));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      return await completer.future;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Firebase phone OTP for registration — sends OTP and returns verificationId.
  Future<String> sendPhoneOtpAndGetVerificationId({
    required String phoneNumber,
    required String countryCode,
  }) async {
    final completer = Completer<String>();
    try {
      _firebaseAuth.verifyPhoneNumber(
        phoneNumber: "$countryCode$phoneNumber",
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(ApiException(message: e.message ?? e.code));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      return await completer.future;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Verify Firebase phone OTP using verificationId + smsCode.
  Future<void> verifyFirebasePhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw ApiException(message: e.message ?? e.code);
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /verify_email — verifies email OTP after registration.
  Future<AuthModel> verifyEmail({
    required String email,
    required String otp,
  }) async {
    try {
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.verifyEmail,
        data: {
          ApiParameters.email: email,
          ApiParameters.code: otp,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Firebase phone OTP verification — verifies OTP and logs in user.
  Future<AuthModel> verifyPhoneOtp({
    required String phoneNumber,
    required String type,
    required String phoneAuthType,
    String? languageId,
    required String countryCode,
  }) async {
    try {
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          ApiParameters.id: phoneNumber,
          ApiParameters.type: type,
          ApiParameters.phoneAuthType: phoneAuthType,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
          ApiParameters.countryCode: countryCode,
          if (languageId != null && languageId.isNotEmpty)
            ApiParameters.languageId: languageId,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /login — returns full login response with token and delivery boy data.
  Future<AuthModel> loginWithEmailPassword({
    required String id,
    required String password,
    required String type,
    String? languageId,
  }) async {
    try {
      String? fcmToken = await getFcmToken();
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          ApiParameters.id: id,
          ApiParameters.password: password,
          ApiParameters.type: type,
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: AppConstants.platformType,
          if (languageId != null && languageId.isNotEmpty)
            ApiParameters.languageId: languageId,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /signUp — multipart upload supporting ID and licence images.
  Future<AuthModel> signUp({
    required String name,
    String? mobile,
    String? password,
    String? type,
    String? email,
    String? profileImagePath,
    String? friendsCode,
    String? phoneAuthType,
    String? languageId,
    String? countryCode,
    String? countryId,
  }) async {
    try {
      String? fcmToken = await getFcmToken();

      final Map<String, dynamic> fields = {
        ApiParameters.name: name,
        ApiParameters.mobile: mobile,
        ApiParameters.password: password,
        ApiParameters.type: type,
        ApiParameters.fcmToken: fcmToken,
        ApiParameters.platform: AppConstants.platformType,
        ApiParameters.friendsCode: friendsCode,
        ApiParameters.languageId: languageId,
        if (mobile != null &&
            mobile.trim().isNotEmpty &&
            countryCode != null &&
            countryCode.isNotEmpty)
          ApiParameters.countryCode: countryCode,
        if (countryId != null && countryId.isNotEmpty)
          ApiParameters.countryId: countryId,
      };

      if (email != null && email.trim().isNotEmpty) {
        fields[ApiParameters.email] = email;
      }

      if (type == "phone") {
        fields[ApiParameters.phoneAuthType] = phoneAuthType;
        if (mobile != null &&
            mobile.trim().isNotEmpty &&
            countryCode != null &&
            countryCode.isNotEmpty) {
          fields[ApiParameters.countryCode] = countryCode;
        }
      }

      if (profileImagePath != null) {
        fields[ApiParameters.profile] = await MultipartFile.fromFile(
          profileImagePath,
          filename: profileImagePath.split('/').last,
        );
      }

      final response = await _apiClient.upload(
        ApiEndpoints.register,
        formData: FormData.fromMap(fields),
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /verify_user_exist — check if phone user exists before sending forgot-password OTP.
  Future<Map<String, dynamic>> verifyUserExist({
    required String mobile,
    required String countryCode,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyUserExist,
        data: {
          ApiParameters.type: 'phone',
          ApiParameters.mobile: mobile,
          ApiParameters.countryCode: countryCode,
        },
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /send_email_forgot_password_otp — send OTP to email for password reset.
  Future<Map<String, dynamic>> sendEmailForgotPasswordOtp({
    required String email,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.sendEmailForgotPasswordOtp,
        data: {ApiParameters.email: email},
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /send_sms — send Custom SMS OTP for forgot-password phone flow.
  Future<void> sendCustomSmsForgotPasswordOtp({
    required String mobile,
    required String countryCode,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.sendSms,
        data: {
          ApiParameters.mobile: mobile,
          ApiParameters.countryCode: countryCode,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /verify_user — verify Custom SMS OTP for forgot-password (no auth saved).
  Future<void> verifyCustomSmsOtpForForgotPassword({
    required String mobile,
    required String otp,
    required String countryCode,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.verifyUser,
        data: {
          ApiParameters.otp: otp,
          ApiParameters.mobile: mobile,
          ApiParameters.countryCode: countryCode,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /forgot_password — reset password with full params (phone or email flow).
  Future<Map<String, dynamic>> forgotPassword({
    required Map<String, dynamic> params,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.forgotPassword,
        data: params,
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /reset_password — change password with old + new + confirmation.
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.resetPassword,
        data: {
          ApiParameters.oldPassword: oldPassword,
          ApiParameters.newPassword: newPassword,
          ApiParameters.passwordConfirmation: newPasswordConfirmation,
        },
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /edit — fetch authenticated delivery boy profile.
  Future<AuthModel> getProfile() async {
    try {
      final hive = SettingsHiveBox.instance;
      final response = await _apiClient.get(
        ApiEndpoints.userDetails,
        queryParameters: {
          ApiParameters.latitude: hive.userLatitude,
          ApiParameters.longitude: hive.userLongitude,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /add_fcm_token — adds FCM token if not available.
  Future<void> addFcmToken({
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.addFcmToken,
        data: {
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.platform: platform,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /update_fcm_token — updates FCM token and active language on server.
  Future<void> updateFcmToken({
    required String fcmToken,
    required String languageId,
    required String platform,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.updateFcmToken,
        data: {
          ApiParameters.fcmToken: fcmToken,
          ApiParameters.languageId: languageId,
          ApiParameters.platform: platform,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /logout — invalidates the server session token.
  Future<void> logout() async {
    try {
      final fcmToken = AuthHiveBox.instance.fcmToken;
      await _apiClient.post(
        ApiEndpoints.logout,
        data: {ApiParameters.fcmToken: fcmToken},
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /delete_account — permanently deletes the delivery boy account.
  Future<void> deleteAccount() async {
    try {
      await _apiClient.post(ApiEndpoints.deleteAccount);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /update — multipart upload to update delivery boy profile fields.
  Future<AuthModel> updateProfile({
    required String name,
    String? mobile,
    String? email,
    String? profileImagePath,
    String? countryId,
    String? countryCode,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final Map<String, dynamic> fields = {
        ApiParameters.name: name,
        ApiParameters.mobile: mobile,
        ApiParameters.email: email,
        if (countryId != null && countryId.isNotEmpty)
          ApiParameters.countryId: countryId,
        if (mobile != null &&
            mobile.trim().isNotEmpty &&
            countryCode != null &&
            countryCode.isNotEmpty)
          ApiParameters.countryCode: countryCode,
        ApiParameters.latitude: hive.userLatitude,
        ApiParameters.longitude: hive.userLongitude,
      };

      if (profileImagePath != null) {
        fields[ApiParameters.profile] = await MultipartFile.fromFile(
          profileImagePath,
          filename: profileImagePath.split('/').last,
        );
      }

      final response = await _apiClient.upload(
        ApiEndpoints.editProfile,
        formData: FormData.fromMap(fields),
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<AuthModel> customSmsSendPhoneOtp({required String phoneNumber}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.sendSms,
        data: {ApiParameters.mobile: phoneNumber},
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<AuthModel> customSmsVerifyPhoneOtp({
    required String phoneNumber,
    required String otp,
    required String countryCode,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyUser,
        data: {
          ApiParameters.otp: otp,
          ApiParameters.mobile: phoneNumber,
          ApiParameters.countryCode: countryCode,
        },
      );
      return AuthModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
