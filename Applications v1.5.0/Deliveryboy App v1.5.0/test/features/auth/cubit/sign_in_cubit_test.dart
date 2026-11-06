import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  final authModel = AuthModel.fromJson(const {
    'status': 1,
    'message': 'ok',
    'data': {'id': 42, 'name': 'John', 'access_token': 'tok42'},
  });

  // login() persists the session through AuthHiveBox, so every test in this
  // file needs a real (temp-dir) auth box open.
  setUp(() async {
    repository = MockAuthRepository();
    await HiveTestHelper.setUp(authBox);
  });

  tearDown(() => HiveTestHelper.tearDown(authBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  blocTest<SignInCubit, SignInState>(
    'emits [Loading, Loaded] and persists the session on a successful login',
    setUp: () {
      printTestDivider(
        'emits [Loading, Loaded] and persists the session on a successful login',
      );
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
          languageId: any(named: 'languageId'),
        ),
      ).thenAnswer((_) async => authModel);
    },
    build: () => SignInCubit(repository: repository),
    act: (cubit) => cubit.login(email: 'a@a.com', password: 'pass'),
    expect: () => [isA<SignInLoading>(), isA<SignInLoaded>()],
    verify: (_) {
      printTestLog('stored token → expected: "tok42", actual: "${AuthHiveBox.instance.getToken()}"');
      expect(AuthHiveBox.instance.getToken(), 'tok42');
      printTestLog('isLoggedIn   → expected: true, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    },
  );

  blocTest<SignInCubit, SignInState>(
    'emits [Loading, Error] carrying the API message when login fails',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] carrying the API message when login fails',
      );
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
          languageId: any(named: 'languageId'),
        ),
      ).thenThrow(const ApiException(message: 'Invalid credentials'));
    },
    build: () => SignInCubit(repository: repository),
    act: (cubit) => cubit.login(email: 'a@a.com', password: 'wrong'),
    expect: () => [
      isA<SignInLoading>(),
      isA<SignInError>().having(
        (s) => s.message,
        'message',
        'Invalid credentials',
      ),
    ],
    verify: (_) {
      printTestLog('isLoggedIn → expected: false (no session saved), actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    },
  );

  blocTest<SignInCubit, SignInState>(
    'reset() returns the cubit to its initial state',
    setUp: () {
      printTestDivider('reset() returns the cubit to its initial state');
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
          languageId: any(named: 'languageId'),
        ),
      ).thenAnswer((_) async => authModel);
    },
    build: () => SignInCubit(repository: repository),
    act: (cubit) async {
      await cubit.login(email: 'a@a.com', password: 'pass');
      cubit.reset();
    },
    expect: () => [
      isA<SignInLoading>(),
      isA<SignInLoaded>(),
      isA<SignInInitial>(),
    ],
  );
}
