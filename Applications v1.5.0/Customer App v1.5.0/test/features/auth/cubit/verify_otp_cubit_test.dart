import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/cubits/verify_otp_cubit.dart';
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

  test('initial state is VerifyOtpInitial', () {
    printTestDivider('VerifyOtpCubit initial state is VerifyOtpInitial');
    final cubit = VerifyOtpCubit(repository: repository);

    printTestLog(
      'state → expected: VerifyOtpInitial, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<VerifyOtpInitial>());
    cubit.close();
  });

  group('verifyEmail', () {
    blocTest<VerifyOtpCubit, VerifyOtpState>(
      'emits Loading then Loaded, and persists the session, when a token comes back',
      setUp: () {
        when(() => repository.verifyEmail(email: 'a@b.com', otp: '123456'))
            .thenAnswer(
          (_) async => AuthModel(
            message: 'Email verified',
            data: AuthModelData(accessToken: 'tok'),
          ),
        );
      },
      build: () => VerifyOtpCubit(repository: repository),
      act: (cubit) => cubit.verifyEmail(email: 'a@b.com', otp: '123456'),
      expect: () => [
        isA<VerifyOtpLoading>(),
        isA<VerifyOtpLoaded>().having((s) => s.message, 'message', 'Email verified'),
      ],
      verify: (_) {
        printTestLog(
          'token saved → expected: "tok", actual: "${AuthHiveBox.instance.getToken()}"',
        );
        expect(AuthHiveBox.instance.getToken(), 'tok');
      },
    );

    blocTest<VerifyOtpCubit, VerifyOtpState>(
      'emits Error (not Loaded) when the response has no access token',
      setUp: () {
        when(() => repository.verifyEmail(email: 'a@b.com', otp: '000000'))
            .thenAnswer((_) async => AuthModel(message: 'Bad code'));
      },
      build: () => VerifyOtpCubit(repository: repository),
      act: (cubit) => cubit.verifyEmail(email: 'a@b.com', otp: '000000'),
      expect: () => [isA<VerifyOtpLoading>(), isA<VerifyOtpError>()],
    );

    blocTest<VerifyOtpCubit, VerifyOtpState>(
      'surfaces the ApiException message on failure',
      setUp: () {
        when(() => repository.verifyEmail(email: 'a@b.com', otp: '1'))
            .thenThrow(const ApiException(message: 'OTP expired'));
      },
      build: () => VerifyOtpCubit(repository: repository),
      act: (cubit) => cubit.verifyEmail(email: 'a@b.com', otp: '1'),
      expect: () => [
        isA<VerifyOtpLoading>(),
        isA<VerifyOtpError>().having((s) => s.message, 'message', 'OTP expired'),
      ],
    );

    blocTest<VerifyOtpCubit, VerifyOtpState>(
      'emits the generic error message on a non-ApiException error',
      setUp: () {
        when(
          () => repository.verifyEmail(email: 'a@b.com', otp: '1'),
        ).thenThrow(Exception('boom'));
      },
      build: () => VerifyOtpCubit(repository: repository),
      act: (cubit) => cubit.verifyEmail(email: 'a@b.com', otp: '1'),
      expect: () => [isA<VerifyOtpLoading>(), isA<VerifyOtpError>()],
    );
  });

  group('verifyPhoneOtpAndSignUp', () {
    blocTest<VerifyOtpCubit, VerifyOtpState>(
      'verifies the firebase OTP then signs up, persisting the session on success',
      setUp: () {
        when(
          () => repository.verifyFirebasePhoneOtp(
            verificationId: 'vid',
            smsCode: '123456',
          ),
        ).thenAnswer((_) async {});
        when(
          () => repository.signUp(
            name: 'Jordan',
            mobile: '5551234567',
            email: any(named: 'email'),
            password: any(named: 'password'),
            type: 'phone',
            phoneAuthType: 'otp',
            friendsCode: any(named: 'friendsCode'),
            languageId: any(named: 'languageId'),
            countryCode: any(named: 'countryCode'),
            countryId: any(named: 'countryId'),
          ),
        ).thenAnswer(
          (_) async => AuthModel(
            message: 'Registered',
            data: AuthModelData(accessToken: 'new-tok'),
          ),
        );
      },
      build: () => VerifyOtpCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneOtpAndSignUp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'Jordan',
        mobile: '5551234567',
      ),
      expect: () => [
        isA<VerifyOtpLoading>(),
        isA<VerifyOtpLoaded>().having((s) => s.message, 'message', 'Registered'),
      ],
      verify: (_) {
        printTestLog(
          'token saved → expected: "new-tok", actual: "${AuthHiveBox.instance.getToken()}"',
        );
        expect(AuthHiveBox.instance.getToken(), 'new-tok');
      },
    );

    blocTest<VerifyOtpCubit, VerifyOtpState>(
      'emits Error when the OTP itself is rejected by Firebase',
      setUp: () {
        when(
          () => repository.verifyFirebasePhoneOtp(
            verificationId: 'vid',
            smsCode: 'wrong',
          ),
        ).thenThrow(const ApiException(message: 'Invalid code'));
      },
      build: () => VerifyOtpCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneOtpAndSignUp(
        verificationId: 'vid',
        smsCode: 'wrong',
        name: 'Jordan',
        mobile: '5551234567',
      ),
      expect: () => [
        isA<VerifyOtpLoading>(),
        isA<VerifyOtpError>().having((s) => s.message, 'message', 'Invalid code'),
      ],
    );
  });
}
