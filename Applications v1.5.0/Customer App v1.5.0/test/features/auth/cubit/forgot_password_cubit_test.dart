import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/cubits/forgot_password_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is ForgotPasswordInitial', () {
    printTestDivider('ForgotPasswordCubit initial state is ForgotPasswordInitial');
    final cubit = ForgotPasswordCubit(repository: repository);

    printTestLog(
      'state → expected: ForgotPasswordInitial, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<ForgotPasswordInitial>());
    cubit.close();
  });

  group('verifyPhoneAndSendOtp', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'sends a firebase OTP and captures the verificationId when the user exists',
      setUp: () {
        when(
          () => repository.verifyUserExist(
            mobile: '5551234567',
            countryCode: '+1',
          ),
        ).thenAnswer(
          (_) async => {'status': '1', 'message': 'user_already_exist'},
        );
        when(
          () => repository.sendPhoneOtpAndGetVerificationId(
            phoneNumber: '5551234567',
            countryCode: '+1',
          ),
        ).thenAnswer((_) async => 'verification-id-1');
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneAndSendOtp(
        mobile: '5551234567',
        countryCode: '+1',
        isFirebase: true,
      ),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordOtpSent>().having(
          (s) => s.verificationId,
          'verificationId',
          'verification-id-1',
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'sends a custom-SMS OTP (no verificationId) when isFirebase is false',
      setUp: () {
        when(
          () => repository.verifyUserExist(
            mobile: '5551234567',
            countryCode: '+1',
          ),
        ).thenAnswer(
          (_) async => {'status': '1', 'message': 'user_already_exist'},
        );
        when(
          () => repository.sendCustomSmsForgotPasswordOtp(
            mobile: '5551234567',
            countryCode: '+1',
          ),
        ).thenAnswer((_) async {});
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneAndSendOtp(
        mobile: '5551234567',
        countryCode: '+1',
        isFirebase: false,
      ),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordOtpSent>().having(
          (s) => s.verificationId,
          'verificationId',
          isNull,
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits Error with the api message when the user does not exist yet, without sending any OTP',
      setUp: () {
        when(
          () => repository.verifyUserExist(
            mobile: '5559999999',
            countryCode: '+1',
          ),
        ).thenAnswer((_) async => {'status': '0', 'message': 'user_not_found'});
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneAndSendOtp(
        mobile: '5559999999',
        countryCode: '+1',
        isFirebase: true,
      ),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordError>().having((s) => s.message, 'message', 'user_not_found'),
      ],
      verify: (_) {
        verifyNever(
          () => repository.sendPhoneOtpAndGetVerificationId(
            phoneNumber: any(named: 'phoneNumber'),
            countryCode: any(named: 'countryCode'),
          ),
        );
      },
    );
  });

  group('verifyFirebaseOtp', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits Error immediately (no API call) when no verificationId was ever captured',
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.verifyFirebaseOtp(smsCode: '123456'),
      expect: () => [isA<ForgotPasswordError>()],
      verify: (_) {
        verifyNever(
          () => repository.verifyFirebasePhoneOtp(
            verificationId: any(named: 'verificationId'),
            smsCode: any(named: 'smsCode'),
          ),
        );
      },
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'verifies with the captured verificationId once one has been sent',
      setUp: () {
        when(
          () => repository.verifyUserExist(
            mobile: any(named: 'mobile'),
            countryCode: any(named: 'countryCode'),
          ),
        ).thenAnswer(
          (_) async => {'status': '1', 'message': 'user_already_exist'},
        );
        when(
          () => repository.sendPhoneOtpAndGetVerificationId(
            phoneNumber: any(named: 'phoneNumber'),
            countryCode: any(named: 'countryCode'),
          ),
        ).thenAnswer((_) async => 'vid-42');
        when(
          () => repository.verifyFirebasePhoneOtp(
            verificationId: 'vid-42',
            smsCode: '654321',
          ),
        ).thenAnswer((_) async {});
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) async {
        await cubit.verifyPhoneAndSendOtp(
          mobile: '5551234567',
          countryCode: '+1',
          isFirebase: true,
        );
        await cubit.verifyFirebaseOtp(smsCode: '654321');
      },
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordOtpSent>(),
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordOtpVerified>(),
      ],
    );
  });

  group('resetPasswordPhone / resetPasswordEmail', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'resetPasswordPhone emits Success with the api message',
      setUp: () {
        when(
          () => repository.forgotPassword(params: any(named: 'params')),
        ).thenAnswer((_) async => {'status': '1', 'message': 'Password updated'});
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.resetPasswordPhone(
        mobile: '5551234567',
        countryCode: '+1',
        password: 'NewPass123!',
        passwordConfirmation: 'NewPass123!',
        otpVerifyMethod: 'firebase',
      ),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordSuccess>().having(
          (s) => s.message,
          'message',
          'Password updated',
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'resetPasswordEmail surfaces the ApiException message on failure',
      setUp: () {
        when(
          () => repository.forgotPassword(params: any(named: 'params')),
        ).thenThrow(const ApiException(message: 'OTP mismatch'));
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.resetPasswordEmail(
        email: 'a@b.com',
        otp: '111111',
        password: 'NewPass123!',
        passwordConfirmation: 'NewPass123!',
      ),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordError>().having((s) => s.message, 'message', 'OTP mismatch'),
      ],
    );
  });

  group('sendEmailOtp / reset', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'sendEmailOtp emits OtpSent with no verificationId',
      setUp: () {
        when(
          () => repository.sendEmailForgotPasswordOtp(email: 'a@b.com'),
        ).thenAnswer((_) async => {'status': '1'});
      },
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.sendEmailOtp(email: 'a@b.com'),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordOtpSent>().having(
          (s) => s.verificationId,
          'verificationId',
          isNull,
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'reset() returns to Initial from any state',
      build: () => ForgotPasswordCubit(repository: repository),
      act: (cubit) => cubit.reset(),
      expect: () => [isA<ForgotPasswordInitial>()],
    );
  });
}
