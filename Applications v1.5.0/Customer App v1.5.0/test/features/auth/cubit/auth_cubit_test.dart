import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
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

  test('initial state is AuthInitial', () {
    printTestDivider('AuthCubit initial state is AuthInitial');
    final cubit = AuthCubit(repository: repository);

    printTestLog('state → expected: AuthInitial, actual: ${cubit.state.runtimeType}');
    expect(cubit.state, isA<AuthInitial>());
    cubit.close();
  });

  group('checkAuth', () {
    blocTest<AuthCubit, AuthState>(
      'emits Authenticated when AuthHiveBox has a logged-in user with a token',
      setUp: () async {
        await AuthHiveBox.instance.saveLoginData(
          userLogin: AuthModel(
            data: AuthModelData(accessToken: 'a-real-token'),
          ),
        );
      },
      build: () => AuthCubit(repository: repository),
      act: (cubit) => cubit.checkAuth(),
      expect: () => [isA<AuthAuthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated when nothing has been saved yet',
      build: () => AuthCubit(repository: repository),
      act: (cubit) => cubit.checkAuth(),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated when logged-in flag is set but the token is empty',
      setUp: () async {
        await AuthHiveBox.instance.saveLoginData(
          userLogin: AuthModel(data: AuthModelData(accessToken: '')),
        );
      },
      build: () => AuthCubit(repository: repository),
      act: (cubit) => cubit.checkAuth(),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  });

  group('logout', () {
    blocTest<AuthCubit, AuthState>(
      'calls repository.logout, clears AuthHiveBox, and emits Unauthenticated',
      setUp: () {
        when(() => repository.logout()).thenAnswer((_) async {});
      },
      build: () => AuthCubit(repository: repository),
      act: (cubit) => cubit.logout(),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
      verify: (_) {
        printTestLog(
          'isLoggedIn after logout → expected: false, actual: ${AuthHiveBox.instance.isLoggedIn}',
        );
        expect(AuthHiveBox.instance.isLoggedIn, isFalse);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'still clears local auth and emits Unauthenticated even when the API call throws',
      setUp: () {
        when(() => repository.logout()).thenThrow(Exception('network down'));
      },
      build: () => AuthCubit(repository: repository),
      act: (cubit) => cubit.logout(),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
      verify: (_) {
        printTestLog(
          'isLoggedIn after logout (API failed) → expected: false, actual: ${AuthHiveBox.instance.isLoggedIn}',
        );
        expect(AuthHiveBox.instance.isLoggedIn, isFalse);
      },
    );
  });
}
