import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/models/auth_model.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() async {
    repository = MockAuthRepository();
    await HiveTestHelper.setUp(authBox);
  });

  tearDown(() => HiveTestHelper.tearDown(authBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is CustomSmsVerifyPhoneOtpInitial', () {
    printTestDivider(
      'CustomSmsVerifyPhoneOtpCubit initial state is CustomSmsVerifyPhoneOtpInitial',
    );
    final cubit = CustomSmsVerifyPhoneOtpCubit(repository: repository);

    expect(cubit.state, isA<CustomSmsVerifyPhoneOtpInitial>());
    cubit.close();
  });

  blocTest<CustomSmsVerifyPhoneOtpCubit, CustomSmsVerifyPhoneOtpState>(
    'emits Loading then Loaded and persists the session on success',
    setUp: () {
      when(
        () => repository.customSmsVerifyPhoneOtp(
          phoneNumber: '5551234567',
          otp: '123456',
          countryCode: '+1',
        ),
      ).thenAnswer(
        (_) async => AuthModel(data: AuthModelData(accessToken: 'sms-tok')),
      );
    },
    build: () => CustomSmsVerifyPhoneOtpCubit(repository: repository),
    act: (cubit) => cubit.customSmsVerifyPhoneOtp(
      phoneNumber: '5551234567',
      otp: '123456',
      countryCode: '+1',
    ),
    expect: () => [
      isA<CustomSmsVerifyPhoneOtpLoading>(),
      isA<CustomSmsVerifyPhoneOtpLoaded>(),
    ],
    verify: (_) {
      printTestLog(
        'token saved → expected: "sms-tok", actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken(), 'sms-tok');
    },
  );

  blocTest<CustomSmsVerifyPhoneOtpCubit, CustomSmsVerifyPhoneOtpState>(
    'surfaces the ApiException message on a wrong code, without touching the session',
    setUp: () {
      when(
        () => repository.customSmsVerifyPhoneOtp(
          phoneNumber: '5551234567',
          otp: '000000',
          countryCode: '+1',
        ),
      ).thenThrow(const ApiException(message: 'Incorrect code'));
    },
    build: () => CustomSmsVerifyPhoneOtpCubit(repository: repository),
    act: (cubit) => cubit.customSmsVerifyPhoneOtp(
      phoneNumber: '5551234567',
      otp: '000000',
      countryCode: '+1',
    ),
    expect: () => [
      isA<CustomSmsVerifyPhoneOtpLoading>(),
      isA<CustomSmsVerifyPhoneOtpError>().having(
        (s) => s.message,
        'message',
        'Incorrect code',
      ),
    ],
    verify: (_) {
      printTestLog(
        'token after failed verify → expected: null, actual: ${AuthHiveBox.instance.getToken()}',
      );
      expect(AuthHiveBox.instance.getToken(), isNull);
    },
  );
}
