import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

/// `AuthRepository`'s default constructor falls back to `FirebaseAuth.instance`
/// whenever `firebaseAuth` isn't supplied — that getter throws without a real
/// Firebase app initialized, so every repository test below passes a mock
/// explicitly, even though none of the methods under test touch it.
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockApiClient mockApiClient;
  late MockFirebaseAuth mockFirebaseAuth;
  late AuthRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/auth/login_success.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUpAll(() {
    registerApiClientFallbackValues();
  });

  setUp(() {
    mockApiClient = MockApiClient();
    mockFirebaseAuth = MockFirebaseAuth();
    repository = AuthRepository(
      apiClient: mockApiClient,
      firebaseAuth: mockFirebaseAuth,
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  // Every method below is one of the handful on `AuthRepository` that does
  // *not* start by calling `getFcmToken()` (which hits real
  // `FirebaseMessaging.instance` and throws under `flutter test` with no
  // platform channel registered). `login*`/`signUp`/`verifyEmail`/
  // `verifyPhoneOtp` all call it first and are therefore covered instead at
  // the cubit layer, where `AuthRepository` itself is mocked wholesale and
  // Firebase never enters the picture — see the "Bugs / gotchas" section of
  // TESTING.md for the full explanation.

  group('verifyUserExist', () {
    test('POSTs to verify_user_exist with type=phone/mobile/country_code', () async {
      printTestDivider(
        'verifyUserExist POSTs to verify_user_exist with type=phone/mobile/country_code',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.verifyUserExist,
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => {'status': '1', 'message': 'user_already_exist'},
      );

      final result = await repository.verifyUserExist(
        mobile: '5551234567',
        countryCode: '+1',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.verifyUserExist,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('type → expected: "phone", actual: "${captured[ApiParameters.type]}"');
      expect(captured[ApiParameters.type], 'phone');
      printTestLog(
        'mobile → expected: "5551234567", actual: "${captured[ApiParameters.mobile]}"',
      );
      expect(captured[ApiParameters.mobile], '5551234567');
      printTestLog('result message → expected: "user_already_exist", actual: "${result['message']}"');
      expect(result['message'], 'user_already_exist');
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider(
        'verifyUserExist an ApiException from the client rethrows as-is',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.verifyUserExist,
          data: any(named: 'data'),
        ),
      ).thenThrow(const ApiException(message: 'user not found'));

      expect(
        () => repository.verifyUserExist(mobile: '1', countryCode: '+1'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'user not found'),
        ),
      );
    });

    test('a non-ApiException error is wrapped via ApiException.fromDioError', () async {
      printTestDivider(
        'verifyUserExist a non-ApiException error is wrapped via ApiException.fromDioError',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.verifyUserExist,
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('boom'));

      expect(
        () => repository.verifyUserExist(mobile: '1', countryCode: '+1'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('sendEmailForgotPasswordOtp', () {
    test('POSTs the email to send_email_forgot_password_otp', () async {
      printTestDivider(
        'sendEmailForgotPasswordOtp POSTs the email to send_email_forgot_password_otp',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.sendEmailForgotPasswordOtp,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.sendEmailForgotPasswordOtp(email: 'a@b.com');

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.sendEmailForgotPasswordOtp,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('email → expected: "a@b.com", actual: "${captured[ApiParameters.email]}"');
      expect(captured[ApiParameters.email], 'a@b.com');
    });
  });

  group('sendCustomSmsForgotPasswordOtp', () {
    test('POSTs mobile/country_code to send_sms', () async {
      printTestDivider(
        'sendCustomSmsForgotPasswordOtp POSTs mobile/country_code to send_sms',
      );
      when(
        () => mockApiClient.post(ApiEndpoints.sendSms, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.sendCustomSmsForgotPasswordOtp(
        mobile: '5559876543',
        countryCode: '+1',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.sendSms,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'mobile → expected: "5559876543", actual: "${captured[ApiParameters.mobile]}"',
      );
      expect(captured[ApiParameters.mobile], '5559876543');
      printTestLog(
        'countryCode → expected: "+1", actual: "${captured[ApiParameters.countryCode]}"',
      );
      expect(captured[ApiParameters.countryCode], '+1');
    });
  });

  group('verifyCustomSmsOtpForForgotPassword', () {
    test('POSTs otp/mobile/country_code to verify_user', () async {
      printTestDivider(
        'verifyCustomSmsOtpForForgotPassword POSTs otp/mobile/country_code to verify_user',
      );
      when(
        () => mockApiClient.post(ApiEndpoints.verifyUser, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.verifyCustomSmsOtpForForgotPassword(
        mobile: '5559876543',
        otp: '123456',
        countryCode: '+1',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.verifyUser,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('otp → expected: "123456", actual: "${captured[ApiParameters.otp]}"');
      expect(captured[ApiParameters.otp], '123456');
    });
  });

  group('forgotPassword', () {
    test('POSTs the raw params map through as-is to forgot_password', () async {
      printTestDivider(
        'forgotPassword POSTs the raw params map through as-is to forgot_password',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.forgotPassword,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': '1', 'message': 'Password reset'});

      final params = {ApiParameters.email: 'a@b.com', ApiParameters.otp: '1'};
      final result = await repository.forgotPassword(params: params);

      verify(
        () => mockApiClient.post(ApiEndpoints.forgotPassword, data: params),
      ).called(1);
      printTestLog('message → expected: "Password reset", actual: "${result['message']}"');
      expect(result['message'], 'Password reset');
    });
  });

  group('changePassword', () {
    test('POSTs old/new/confirmation to reset_password', () async {
      printTestDivider(
        'changePassword POSTs old/new/confirmation to reset_password',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.resetPassword,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.changePassword(
        oldPassword: 'old',
        newPassword: 'new',
        newPasswordConfirmation: 'new',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.resetPassword,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('oldPassword → expected: "old", actual: "${captured[ApiParameters.oldPassword]}"');
      expect(captured[ApiParameters.oldPassword], 'old');
      printTestLog(
        'passwordConfirmation → expected: "new", actual: "${captured[ApiParameters.passwordConfirmation]}"',
      );
      expect(captured[ApiParameters.passwordConfirmation], 'new');
    });
  });

  group('getProfile', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('GETs user_details with the cached lat/lng and parses the response', () async {
      printTestDivider(
        'getProfile GETs user_details with the cached lat/lng and parses the response',
      );
      when(
        () => mockApiClient.get(
          ApiEndpoints.userDetails,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => fixture());

      final model = await repository.getProfile();

      final captured =
          verify(
                () => mockApiClient.get(
                  ApiEndpoints.userDetails,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'queryParameters latitude key present → expected: true, actual: ${captured.containsKey(ApiParameters.latitude)}',
      );
      expect(captured.containsKey(ApiParameters.latitude), isTrue);
      printTestLog(
        'model.data.email → expected: "jordan.blake@example.com", actual: "${model.data?.email}"',
      );
      expect(model.data?.email, 'jordan.blake@example.com');
    });
  });

  group('addFcmToken', () {
    test('POSTs fcm_token/platform to add_fcm_token', () async {
      printTestDivider('addFcmToken POSTs fcm_token/platform to add_fcm_token');
      when(
        () => mockApiClient.post(
          ApiEndpoints.addFcmToken,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.addFcmToken(fcmToken: 'tok123', platform: 'android');

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.addFcmToken,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('fcmToken → expected: "tok123", actual: "${captured[ApiParameters.fcmToken]}"');
      expect(captured[ApiParameters.fcmToken], 'tok123');
    });
  });

  group('updateFcmToken', () {
    test('POSTs fcm_token/language_id/platform to update_fcm_token', () async {
      printTestDivider(
        'updateFcmToken POSTs fcm_token/language_id/platform to update_fcm_token',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.updateFcmToken,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.updateFcmToken(
        fcmToken: 'tok123',
        languageId: '1',
        platform: 'ios',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.updateFcmToken,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'languageId → expected: "1", actual: "${captured[ApiParameters.languageId]}"',
      );
      expect(captured[ApiParameters.languageId], '1');
    });
  });

  group('logout', () {
    setUp(() => HiveTestHelper.setUp(authBox));
    tearDown(() => HiveTestHelper.tearDown(authBox));

    test('POSTs the cached fcm token from AuthHiveBox to logout', () async {
      printTestDivider(
        'logout POSTs the cached fcm token from AuthHiveBox to logout',
      );
      await AuthHiveBox.instance.setFcmToken('cached-fcm-token');
      when(
        () => mockApiClient.post(ApiEndpoints.logout, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.logout();

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.logout,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'fcmToken → expected: "cached-fcm-token", actual: "${captured[ApiParameters.fcmToken]}"',
      );
      expect(captured[ApiParameters.fcmToken], 'cached-fcm-token');
    });
  });

  group('deleteAccount', () {
    test('POSTs to delete_account with no body', () async {
      printTestDivider('deleteAccount POSTs to delete_account with no body');
      when(
        () => mockApiClient.post(ApiEndpoints.deleteAccount),
      ).thenAnswer((_) async => {'status': '1'});

      await repository.deleteAccount();

      verify(() => mockApiClient.post(ApiEndpoints.deleteAccount)).called(1);
    });
  });

  group('updateProfile', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('uploads multipart form data to edit_profile and parses the response', () async {
      printTestDivider(
        'updateProfile uploads multipart form data to edit_profile and parses the response',
      );
      when(
        () => mockApiClient.upload(
          ApiEndpoints.editProfile,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => fixture());

      final model = await repository.updateProfile(
        name: 'Jordan Blake',
        mobile: '5551234567',
        email: 'jordan.blake@example.com',
      );

      verify(
        () => mockApiClient.upload(
          ApiEndpoints.editProfile,
          formData: any(named: 'formData'),
        ),
      ).called(1);
      printTestLog(
        'model.data.name → expected: "Jordan Blake", actual: "${model.data?.name}"',
      );
      expect(model.data?.name, 'Jordan Blake');
    });
  });

  group('customSmsSendPhoneOtp', () {
    test('POSTs mobile to send_sms and parses an AuthModel', () async {
      printTestDivider(
        'customSmsSendPhoneOtp POSTs mobile to send_sms and parses an AuthModel',
      );
      when(
        () => mockApiClient.post(ApiEndpoints.sendSms, data: any(named: 'data')),
      ).thenAnswer((_) async => fixture());

      final model = await repository.customSmsSendPhoneOtp(
        phoneNumber: '5551234567',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.sendSms,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'mobile → expected: "5551234567", actual: "${captured[ApiParameters.mobile]}"',
      );
      expect(captured[ApiParameters.mobile], '5551234567');
      printTestLog(
        'model.data.accessToken → expected: non-empty, actual: "${model.data?.accessToken}"',
      );
      expect(model.data?.accessToken, isNotEmpty);
    });
  });

  group('customSmsVerifyPhoneOtp', () {
    test('POSTs otp/mobile/country_code to verify_user and parses an AuthModel', () async {
      printTestDivider(
        'customSmsVerifyPhoneOtp POSTs otp/mobile/country_code to verify_user and parses an AuthModel',
      );
      when(
        () => mockApiClient.post(ApiEndpoints.verifyUser, data: any(named: 'data')),
      ).thenAnswer((_) async => fixture());

      final model = await repository.customSmsVerifyPhoneOtp(
        phoneNumber: '5551234567',
        otp: '654321',
        countryCode: '+1',
      );

      final captured =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.verifyUser,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('otp → expected: "654321", actual: "${captured[ApiParameters.otp]}"');
      expect(captured[ApiParameters.otp], '654321');
      printTestLog(
        'model.data.email → expected: non-empty, actual: "${model.data?.email}"',
      );
      expect(model.data?.email, isNotEmpty);
    });
  });
}
