import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/cubit/change_password_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> callChange(ChangePasswordCubit cubit) => cubit.changePassword(
    oldPassword: 'old1',
    password: 'new1',
    confirmPassword: 'new1',
  );

  void stubChangePassword(Map<String, dynamic> response) {
    when(
      () => repository.changePassword(
        oldPassword: any(named: 'oldPassword'),
        password: any(named: 'password'),
        confirmPassword: any(named: 'confirmPassword'),
      ),
    ).thenAnswer((_) async => response);
  }

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits [Loading, Loaded] carrying the server message on success',
    setUp: () {
      printTestDivider(
        'emits [Loading, Loaded] carrying the server message on success',
      );
      stubChangePassword({'status': 1, 'message': 'Password changed'});
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: callChange,
    expect: () => [
      isA<ChangePasswordLoading>(),
      isA<ChangePasswordLoaded>().having(
        (s) => s.data,
        'data',
        'Password changed',
      ),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'falls back to the localized message when the response has none',
    setUp: () {
      printTestDivider(
        'falls back to the localized message when the response has none',
      );
      stubChangePassword({'status': 1});
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: callChange,
    expect: () => [
      isA<ChangePasswordLoading>(),
      isA<ChangePasswordLoaded>().having(
        (s) => s.data,
        'data is a non-empty fallback',
        isNotEmpty,
      ),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits [Loading, Error] carrying the API message on failure',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] carrying the API message on failure',
      );
      when(
        () => repository.changePassword(
          oldPassword: any(named: 'oldPassword'),
          password: any(named: 'password'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenThrow(const ApiException(message: 'Old password is incorrect'));
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: callChange,
    expect: () => [
      isA<ChangePasswordLoading>(),
      isA<ChangePasswordError>().having(
        (s) => s.message,
        'message',
        'Old password is incorrect',
      ),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'reset() returns the cubit to its initial state',
    setUp: () {
      printTestDivider('reset() returns the cubit to its initial state');
      stubChangePassword({'status': 1, 'message': 'Password changed'});
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: (cubit) async {
      await callChange(cubit);
      cubit.reset();
    },
    expect: () => [
      isA<ChangePasswordLoading>(),
      isA<ChangePasswordLoaded>(),
      isA<ChangePasswordInitial>(),
    ],
  );
}
