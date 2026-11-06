import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/cubit/forgot_password_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'emits [Loading, Loaded] carrying the server message on success',
    setUp: () {
      printTestDivider(
        'emits [Loading, Loaded] carrying the server message on success',
      );
      when(
        () => repository.forgotPassword(email: any(named: 'email')),
      ).thenAnswer((_) async => {'status': 1, 'message': 'OTP sent'});
    },
    build: () => ForgotPasswordCubit(repository: repository),
    act: (cubit) => cubit.forgotPassword('a@a.com'),
    expect: () => [
      isA<ForgotPasswordLoading>(),
      isA<ForgotPasswordLoaded>().having((s) => s.data, 'data', 'OTP sent'),
    ],
  );

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'falls back to the localized message when the response has none',
    setUp: () {
      printTestDivider(
        'falls back to the localized message when the response has none',
      );
      when(
        () => repository.forgotPassword(email: any(named: 'email')),
      ).thenAnswer((_) async => {'status': 1});
    },
    build: () => ForgotPasswordCubit(repository: repository),
    act: (cubit) => cubit.forgotPassword('a@a.com'),
    expect: () => [
      isA<ForgotPasswordLoading>(),
      isA<ForgotPasswordLoaded>().having(
        (s) => s.data,
        'data is a non-empty fallback',
        isNotEmpty,
      ),
    ],
  );

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'emits [Loading, Error] carrying the API message on failure',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] carrying the API message on failure',
      );
      when(
        () => repository.forgotPassword(email: any(named: 'email')),
      ).thenThrow(const ApiException(message: 'Email not found'));
    },
    build: () => ForgotPasswordCubit(repository: repository),
    act: (cubit) => cubit.forgotPassword('nope@a.com'),
    expect: () => [
      isA<ForgotPasswordLoading>(),
      isA<ForgotPasswordError>().having(
        (s) => s.message,
        'message',
        'Email not found',
      ),
    ],
  );

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'reset() returns the cubit to its initial state',
    setUp: () {
      printTestDivider('reset() returns the cubit to its initial state');
      when(
        () => repository.forgotPassword(email: any(named: 'email')),
      ).thenAnswer((_) async => {'status': 1, 'message': 'OTP sent'});
    },
    build: () => ForgotPasswordCubit(repository: repository),
    act: (cubit) async {
      await cubit.forgotPassword('a@a.com');
      cubit.reset();
    },
    expect: () => [
      isA<ForgotPasswordLoading>(),
      isA<ForgotPasswordLoaded>(),
      isA<ForgotPasswordInitial>(),
    ],
  );
}
