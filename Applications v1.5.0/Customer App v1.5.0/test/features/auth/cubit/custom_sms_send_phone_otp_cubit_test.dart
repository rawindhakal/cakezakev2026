import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/models/auth_model.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is CustomSmsSendPhoneOtpInitial', () {
    printTestDivider(
      'CustomSmsSendPhoneOtpCubit initial state is CustomSmsSendPhoneOtpInitial',
    );
    final cubit = CustomSmsSendPhoneOtpCubit(repository: repository);

    expect(cubit.state, isA<CustomSmsSendPhoneOtpInitial>());
    cubit.close();
  });

  blocTest<CustomSmsSendPhoneOtpCubit, CustomSmsSendPhoneOtpState>(
    'emits Loading then Loaded with the parsed AuthModel on success',
    setUp: () {
      when(
        () => repository.customSmsSendPhoneOtp(phoneNumber: '+15551234567'),
      ).thenAnswer((_) async => AuthModel(message: 'OTP sent'));
    },
    build: () => CustomSmsSendPhoneOtpCubit(repository: repository),
    act: (cubit) =>
        cubit.customSmsSendPhoneOtp(phoneNumber: '+15551234567'),
    expect: () => [
      isA<CustomSmsSendPhoneOtpLoading>(),
      isA<CustomSmsSendPhoneOtpLoaded>().having(
        (s) => s.user.message,
        'user.message',
        'OTP sent',
      ),
    ],
  );

  blocTest<CustomSmsSendPhoneOtpCubit, CustomSmsSendPhoneOtpState>(
    'surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.customSmsSendPhoneOtp(phoneNumber: '+15551234567'),
      ).thenThrow(const ApiException(message: 'SMS gateway unavailable'));
    },
    build: () => CustomSmsSendPhoneOtpCubit(repository: repository),
    act: (cubit) =>
        cubit.customSmsSendPhoneOtp(phoneNumber: '+15551234567'),
    expect: () => [
      isA<CustomSmsSendPhoneOtpLoading>(),
      isA<CustomSmsSendPhoneOtpError>().having(
        (s) => s.message,
        'message',
        'SMS gateway unavailable',
      ),
    ],
  );

  blocTest<CustomSmsSendPhoneOtpCubit, CustomSmsSendPhoneOtpState>(
    'reset() returns to Initial',
    build: () => CustomSmsSendPhoneOtpCubit(repository: repository),
    act: (cubit) => cubit.reset(),
    expect: () => [isA<CustomSmsSendPhoneOtpInitial>()],
  );
}
