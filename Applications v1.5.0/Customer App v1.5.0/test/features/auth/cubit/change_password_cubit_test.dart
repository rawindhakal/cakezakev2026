import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/cubits/change_password_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is ChangePasswordInitial', () {
    printTestDivider('ChangePasswordCubit initial state is ChangePasswordInitial');
    final cubit = ChangePasswordCubit(repository: repository);

    expect(cubit.state, isA<ChangePasswordInitial>());
    cubit.close();
  });

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits Loading then Loaded with the api message on success',
    setUp: () {
      when(
        () => repository.changePassword(
          oldPassword: 'old',
          newPassword: 'new',
          newPasswordConfirmation: 'new',
        ),
      ).thenAnswer((_) async => {'message': 'Password changed'});
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: (cubit) => cubit.changePassword(
      oldPassword: 'old',
      newPassword: 'new',
      newPasswordConfirmation: 'new',
    ),
    expect: () => [
      isA<ChangePasswordLoading>(),
      isA<ChangePasswordLoaded>().having((s) => s.message, 'message', 'Password changed'),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'falls back to the localized success message when the api sends no message',
    setUp: () {
      when(
        () => repository.changePassword(
          oldPassword: 'old',
          newPassword: 'new',
          newPasswordConfirmation: 'new',
        ),
      ).thenAnswer((_) async => {});
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: (cubit) => cubit.changePassword(
      oldPassword: 'old',
      newPassword: 'new',
      newPasswordConfirmation: 'new',
    ),
    expect: () => [
      isA<ChangePasswordLoading>(),
      isA<ChangePasswordLoaded>().having((s) => s.message, 'message', isNotEmpty),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'surfaces the ApiException message on failure (e.g. wrong old password)',
    setUp: () {
      when(
        () => repository.changePassword(
          oldPassword: 'wrong',
          newPassword: 'new',
          newPasswordConfirmation: 'new',
        ),
      ).thenThrow(const ApiException(message: 'Old password is incorrect'));
    },
    build: () => ChangePasswordCubit(repository: repository),
    act: (cubit) => cubit.changePassword(
      oldPassword: 'wrong',
      newPassword: 'new',
      newPasswordConfirmation: 'new',
    ),
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
    'reset() returns to Initial',
    build: () => ChangePasswordCubit(repository: repository),
    act: (cubit) => cubit.reset(),
    expect: () => [isA<ChangePasswordInitial>()],
  );
}
