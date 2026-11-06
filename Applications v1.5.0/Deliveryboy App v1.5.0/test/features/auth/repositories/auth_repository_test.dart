import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late AuthRepository repository;

  setUpAll(() {
    registerApiClientFallbackValues();
  });

  setUp(() {
    mockApiClient = MockApiClient();
    repository = AuthRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('login', () {
    test('sends email/password/type=3 and parses the AuthModel response', () async {
      printTestDivider(
        'login sends email/password/type=3 and parses the AuthModel response',
      );
      when(
        () => mockApiClient.post(ApiEndpoints.login, data: any(named: 'data')),
      ).thenAnswer(
        (_) async => {
          'status': 1,
          'message': 'ok',
          'data': {'id': 1, 'access_token': 'tok'},
        },
      );

      final result = await repository.login(
        email: 'a@a.com',
        password: 'pass123',
        fcmToken: 'fcm1',
        platform: 'android',
        languageId: '1',
      );

      final captured = verify(
        () => mockApiClient.post(
          ApiEndpoints.login,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;

      printTestLog('data[email]    → expected: "a@a.com", actual: "${captured[ApiParameters.email]}"');
      expect(captured[ApiParameters.email], 'a@a.com');
      printTestLog('data[password] → expected: "pass123", actual: "${captured[ApiParameters.password]}"');
      expect(captured[ApiParameters.password], 'pass123');
      printTestLog('data[type]     → expected: "3", actual: "${captured[ApiParameters.type]}"');
      expect(captured[ApiParameters.type], '3');
      printTestLog('data[fcmToken] → expected: "fcm1", actual: "${captured[ApiParameters.fcmToken]}"');
      expect(captured[ApiParameters.fcmToken], 'fcm1');
      printTestLog('result.data.accessToken → expected: "tok", actual: "${result.data?.accessToken}"');
      expect(result.data?.accessToken, 'tok');
    });

    test('omits fcmToken/platform/languageId when null or empty', () async {
      printTestDivider('login omits fcmToken/platform/languageId when null or empty');
      when(
        () => mockApiClient.post(ApiEndpoints.login, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': 1, 'message': 'ok'});

      await repository.login(email: 'a@a.com', password: 'pass123');

      final captured = verify(
        () => mockApiClient.post(
          ApiEndpoints.login,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;

      printTestLog(
        'data.containsKey(fcmToken) → expected: false, actual: ${captured.containsKey(ApiParameters.fcmToken)}',
      );
      expect(captured.containsKey(ApiParameters.fcmToken), isFalse);
    });
  });

  group('register', () {
    test('includes bonus fields only when bonusType == "1"', () async {
      printTestDivider('register includes bonus fields only when bonusType == "1"');
      when(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Registered'});

      await repository.register(
        name: 'John',
        mobile: '999',
        password: 'p1',
        confirmPassword: 'p1',
        bonusType: '1',
        bonusPercentage: '10',
        bonusMinAmount: '5',
        bonusMaxAmount: '50',
      );

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      final fieldMap = {for (final f in captured.fields) f.key: f.value};
      printTestLog(
        'fields[bonusPercentage] → expected: "10", actual: "${fieldMap[ApiParameters.bonusPercentage]}"',
      );
      expect(fieldMap[ApiParameters.bonusPercentage], '10');
      printTestLog(
        'fields[bonusMinAmount]  → expected: "5", actual: "${fieldMap[ApiParameters.bonusMinAmount]}"',
      );
      expect(fieldMap[ApiParameters.bonusMinAmount], '5');
    });

    test('omits bonus percentage/min/max fields when bonusType != "1"', () async {
      printTestDivider('register omits bonus fields when bonusType != "1"');
      when(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Registered'});

      await repository.register(
        name: 'John',
        mobile: '999',
        password: 'p1',
        confirmPassword: 'p1',
        bonusType: '2',
        bonusPercentage: '10',
      );

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      final keys = captured.fields.map((f) => f.key).toSet();
      printTestLog(
        'fields.contains(bonusPercentage) → expected: false, actual: ${keys.contains(ApiParameters.bonusPercentage)}',
      );
      expect(keys.contains(ApiParameters.bonusPercentage), isFalse);
    });

    test('attaches profile, national ID and driving licence images as files', () async {
      printTestDivider(
        'register attaches profile, national ID and driving licence images as files',
      );
      when(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Registered'});

      // MultipartFile.fromFile reads from disk, so these have to be real files.
      final tempDir = await Directory.systemTemp.createTemp('register_images_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File file(String name) =>
          File('${tempDir.path}/$name')..writeAsBytesSync([1, 2, 3]);

      await repository.register(
        name: 'John',
        mobile: '999',
        password: 'p1',
        confirmPassword: 'p1',
        bonusType: '0',
        profileImagePath: file('profile.png').path,
        nationalIdImagePath: file('national-id.png').path,
        drivingLicenseImagePath: file('licence.png').path,
      );

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      final fileKeys = captured.files.map((f) => f.key).toSet();
      printTestLog('files → expected: profile, national ID, licence; actual: $fileKeys');
      expect(fileKeys, contains(ApiParameters.profile));
      expect(fileKeys, contains(ApiParameters.nationalIdentityCard));
      expect(fileKeys, contains(ApiParameters.drivingLicense));

      final profileFile = captured.files
          .firstWhere((f) => f.key == ApiParameters.profile)
          .value;
      printTestLog(
        'profile filename → expected: "profile.png", actual: "${profileFile.filename}"',
      );
      expect(profileFile.filename, 'profile.png');
    });

    test('sends no files when no image paths are given', () async {
      printTestDivider('register sends no files when no image paths are given');
      when(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Registered'});

      await repository.register(
        name: 'John',
        mobile: '999',
        password: 'p1',
        confirmPassword: 'p1',
        bonusType: '0',
      );

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.register,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      printTestLog('files.length → expected: 0, actual: ${captured.files.length}');
      expect(captured.files, isEmpty);
    });
  });

  group('updateProfile', () {
    test('sends the required fields and parses the AuthModel response', () async {
      printTestDivider(
        'updateProfile sends the required fields and parses the AuthModel response',
      );
      when(
        () => mockApiClient.upload(
          ApiEndpoints.update,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer(
        (_) async => {
          'status': 1,
          'data': {'id': 3, 'name': 'Updated Name'},
        },
      );

      final result = await repository.updateProfile(
        name: 'Updated Name',
        mobile: '9998887777',
        email: 'updated@example.com',
        bankName: 'Bank of Globe',
      );

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.update,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      final fieldMap = {for (final f in captured.fields) f.key: f.value};
      printTestLog('fields[name]     → expected: "Updated Name", actual: "${fieldMap[ApiParameters.name]}"');
      expect(fieldMap[ApiParameters.name], 'Updated Name');
      printTestLog('fields[bankName] → expected: "Bank of Globe", actual: "${fieldMap[ApiParameters.bankName]}"');
      expect(fieldMap[ApiParameters.bankName], 'Bank of Globe');
      printTestLog('result.data.name → expected: "Updated Name", actual: "${result.data?.name}"');
      expect(result.data?.name, 'Updated Name');
    });

    test('omits optional fields that are null or empty', () async {
      printTestDivider('updateProfile omits optional fields that are null or empty');
      when(
        () => mockApiClient.upload(
          ApiEndpoints.update,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'data': <String, dynamic>{}});

      await repository.updateProfile(name: 'Only Name', mobile: '999', email: '');

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.update,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      final keys = captured.fields.map((f) => f.key).toSet();
      printTestLog('fields.contains(email) → expected: false, actual: ${keys.contains(ApiParameters.email)}');
      expect(keys.contains(ApiParameters.email), isFalse);
      printTestLog('fields.contains(address) → expected: false, actual: ${keys.contains(ApiParameters.address)}');
      expect(keys.contains(ApiParameters.address), isFalse);
    });

    test('includes bonus fields only when bonusType == "1"', () async {
      printTestDivider('updateProfile includes bonus fields only when bonusType == "1"');
      when(
        () => mockApiClient.upload(
          ApiEndpoints.update,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'data': <String, dynamic>{}});

      await repository.updateProfile(
        name: 'John',
        mobile: '999',
        bonusType: '0',
        bonusPercentage: '10',
      );

      final captured = verify(
        () => mockApiClient.upload(
          ApiEndpoints.update,
          formData: captureAny(named: 'formData'),
        ),
      ).captured.single as FormData;

      final keys = captured.fields.map((f) => f.key).toSet();
      printTestLog(
        'fields.contains(bonusPercentage) → expected: false, actual: ${keys.contains(ApiParameters.bonusPercentage)}',
      );
      expect(keys.contains(ApiParameters.bonusPercentage), isFalse);
    });
  });

  group('addFcmToken', () {
    test('sends the token and platform', () async {
      printTestDivider('addFcmToken sends the token and platform');
      when(
        () => mockApiClient.post(
          ApiEndpoints.addFcmToken,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.addFcmToken(fcmToken: 'fcm1', platform: 'android');

      verify(
        () => mockApiClient.post(
          ApiEndpoints.addFcmToken,
          data: {
            ApiParameters.fcmToken: 'fcm1',
            ApiParameters.platform: 'android',
          },
        ),
      ).called(1);
    });
  });

  group('updateFcmToken', () {
    test('sends the token, language and platform', () async {
      printTestDivider('updateFcmToken sends the token, language and platform');
      when(
        () => mockApiClient.post(
          ApiEndpoints.updateFcmToken,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.updateFcmToken(
        fcmToken: 'fcm2',
        languageId: '3',
        platform: 'ios',
      );

      verify(
        () => mockApiClient.post(
          ApiEndpoints.updateFcmToken,
          data: {
            ApiParameters.fcmToken: 'fcm2',
            ApiParameters.languageId: '3',
            ApiParameters.platform: 'ios',
          },
        ),
      ).called(1);
    });
  });

  group('forgotPassword', () {
    test('sends email and returns the response message map', () async {
      printTestDivider('forgotPassword sends email and returns the response message map');
      when(
        () => mockApiClient.post(
          ApiEndpoints.forgotPassword,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'OTP sent'});

      final result = await repository.forgotPassword(email: 'a@a.com');

      verify(
        () => mockApiClient.post(
          ApiEndpoints.forgotPassword,
          data: {ApiParameters.email: 'a@a.com'},
        ),
      ).called(1);
      printTestLog('message → expected: "OTP sent", actual: "${result['message']}"');
      expect(result['message'], 'OTP sent');
    });
  });

  group('changePassword', () {
    test('maps old/new/confirm password fields correctly', () async {
      printTestDivider('changePassword maps old/new/confirm password fields correctly');
      when(
        () => mockApiClient.post(
          ApiEndpoints.resetPassword,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Changed'});

      await repository.changePassword(
        oldPassword: 'old1',
        password: 'new1',
        confirmPassword: 'new1',
      );

      verify(
        () => mockApiClient.post(
          ApiEndpoints.resetPassword,
          data: {
            ApiParameters.oldPassword: 'old1',
            ApiParameters.newPassword: 'new1',
            ApiParameters.confirmPassword: 'new1',
          },
        ),
      ).called(1);
    });
  });

  group('getProfile', () {
    test('GETs edit endpoint and parses AuthModel', () async {
      printTestDivider('getProfile GETs edit endpoint and parses AuthModel');
      when(() => mockApiClient.get(ApiEndpoints.editProfile)).thenAnswer(
        (_) async => {
          'status': 1,
          'data': {'id': 7, 'name': 'Jane'},
        },
      );

      final result = await repository.getProfile();

      printTestLog('result.data.name → expected: "Jane", actual: "${result.data?.name}"');
      expect(result.data?.name, 'Jane');
    });
  });

  group('logout', () {
    // logout reads AuthHiveBox.fcmToken to send with the request, so this
    // group needs a real (temp-dir) auth box open — unlike every other
    // method here, which only touches the ApiClient.
    setUp(() => HiveTestHelper.setUp(authBox));
    tearDown(() => HiveTestHelper.tearDown(authBox));

    test('POSTs logout endpoint with the stored FCM token', () async {
      printTestDivider('logout POSTs logout endpoint with the stored FCM token');
      when(
        () => mockApiClient.post(ApiEndpoints.logout, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': 1});

      await repository.logout();

      final captured = verify(
        () => mockApiClient.post(
          ApiEndpoints.logout,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;

      printTestLog(
        'data.containsKey(fcmToken) → expected: true, actual: ${captured.containsKey(ApiParameters.fcmToken)}',
      );
      expect(captured.containsKey(ApiParameters.fcmToken), isTrue);
    });
  });

  group('getDeliveryBoyStatus', () {
    test('parses status when sent as a bare int', () async {
      printTestDivider('getDeliveryBoyStatus parses status when sent as a bare int');
      when(() => mockApiClient.post(ApiEndpoints.getDeliveryBoyStatus)).thenAnswer(
        (_) async => {
          'status': 1,
          'data': {'status': 4, 'remark': 'blocked'},
        },
      );

      final result = await repository.getDeliveryBoyStatus();

      printTestLog('status → expected: 4, actual: ${result.status}');
      expect(result.status, 4);
      printTestLog('remark → expected: "blocked", actual: "${result.remark}"');
      expect(result.remark, 'blocked');
    });

    test('parses status when sent as a quoted string', () async {
      printTestDivider('getDeliveryBoyStatus parses status when sent as a quoted string');
      when(() => mockApiClient.post(ApiEndpoints.getDeliveryBoyStatus)).thenAnswer(
        (_) async => {
          'status': 1,
          'data': {'status': '1'},
        },
      );

      final result = await repository.getDeliveryBoyStatus();

      printTestLog('status → expected: 1, actual: ${result.status}');
      expect(result.status, 1);
    });

    test('throws ApiException when status is missing/null', () async {
      printTestDivider('getDeliveryBoyStatus throws ApiException when status is missing/null');
      when(() => mockApiClient.post(ApiEndpoints.getDeliveryBoyStatus)).thenAnswer(
        (_) async => {
          'status': 1,
          'data': {'remark': 'no status here'},
        },
      );

      printTestLog('expected: throws ApiException, actual: calling now...');
      expect(repository.getDeliveryBoyStatus(), throwsA(isA<ApiException>()));
    });
  });

  group('updateDeliveryBoyStatus', () {
    test('sends the given status', () async {
      printTestDivider('updateDeliveryBoyStatus sends the given status');
      when(
        () => mockApiClient.post(
          ApiEndpoints.updateDeliveryBoyStatus,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.updateDeliveryBoyStatus(status: 1);

      verify(
        () => mockApiClient.post(
          ApiEndpoints.updateDeliveryBoyStatus,
          data: {ApiParameters.status: 1},
        ),
      ).called(1);
    });
  });

  group('deleteAccount', () {
    test('POSTs delete_account endpoint', () async {
      printTestDivider('deleteAccount POSTs delete_account endpoint');
      when(
        () => mockApiClient.post(ApiEndpoints.deleteDeliveryBoyAccount),
      ).thenAnswer((_) async => {'status': 1});

      await repository.deleteAccount();

      verify(() => mockApiClient.post(ApiEndpoints.deleteDeliveryBoyAccount)).called(1);
    });
  });
}
