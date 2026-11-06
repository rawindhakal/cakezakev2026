import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/auth/cubit/auth_cubit.dart';

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

  Future<void> writeSession({required bool loggedIn, String token = 'tok'}) =>
      Hive.box(authBox).putAll({kIsLoggedIn: loggedIn, kToken: token});

  blocTest<AuthCubit, AuthState>(
    'checkAuth emits Authenticated when logged in with a non-empty token',
    setUp: () {
      printTestDivider(
        'checkAuth emits Authenticated when logged in with a non-empty token',
      );
    },
    build: () => AuthCubit(repository: repository),
    act: (cubit) async {
      await writeSession(loggedIn: true);
      cubit.checkAuth();
    },
    expect: () => [isA<AuthAuthenticated>()],
  );

  blocTest<AuthCubit, AuthState>(
    'checkAuth emits Unauthenticated when not logged in',
    setUp: () {
      printTestDivider('checkAuth emits Unauthenticated when not logged in');
    },
    build: () => AuthCubit(repository: repository),
    act: (cubit) async {
      await writeSession(loggedIn: false);
      cubit.checkAuth();
    },
    expect: () => [isA<AuthUnauthenticated>()],
  );

  blocTest<AuthCubit, AuthState>(
    'checkAuth emits Unauthenticated when the stored token is empty',
    setUp: () {
      printTestDivider(
        'checkAuth emits Unauthenticated when the stored token is empty',
      );
    },
    build: () => AuthCubit(repository: repository),
    act: (cubit) async {
      await writeSession(loggedIn: true, token: '');
      cubit.checkAuth();
    },
    expect: () => [isA<AuthUnauthenticated>()],
  );

  blocTest<AuthCubit, AuthState>(
    'logout emits [Loading, Unauthenticated] and clears the local session',
    setUp: () {
      printTestDivider(
        'logout emits [Loading, Unauthenticated] and clears the local session',
      );
      when(() => repository.logout()).thenAnswer((_) async {});
    },
    build: () => AuthCubit(repository: repository),
    act: (cubit) async {
      await writeSession(loggedIn: true);
      await cubit.logout();
    },
    expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    verify: (_) {
      printTestLog('isLoggedIn → expected: false, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isFalse);
      printTestLog('token      → expected: null, actual: ${AuthHiveBox.instance.getToken()}');
      expect(AuthHiveBox.instance.getToken(), isNull);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'logout still clears the local session when the server call throws',
    setUp: () {
      printTestDivider(
        'logout still clears the local session when the server call throws',
      );
      when(
        () => repository.logout(),
      ).thenThrow(const ApiException(message: 'Server unreachable'));
    },
    build: () => AuthCubit(repository: repository),
    act: (cubit) async {
      await writeSession(loggedIn: true);
      await cubit.logout();
    },
    expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    verify: (_) {
      printTestLog('isLoggedIn → expected: false, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    },
  );
}
