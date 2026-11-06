import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/auth/cubit/logout_cubit.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() async {
    repository = MockAuthRepository();
    await HiveTestHelper.setUp(authBox);
    await Hive.box(authBox).putAll({kIsLoggedIn: true, kToken: 'tok'});
  });

  tearDown(() => HiveTestHelper.tearDown(authBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  blocTest<LogoutCubit, LogoutState>(
    'emits [Loading, Loaded] and clears the local session on success',
    setUp: () {
      printTestDivider(
        'emits [Loading, Loaded] and clears the local session on success',
      );
      when(() => repository.logout()).thenAnswer((_) async {});
    },
    build: () => LogoutCubit(repository: repository),
    act: (cubit) => cubit.logout(),
    expect: () => [isA<LogoutLoading>(), isA<LogoutLoaded>()],
    verify: (_) {
      printTestLog('isLoggedIn → expected: false, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    },
  );

  blocTest<LogoutCubit, LogoutState>(
    'emits [Loading, Error] and keeps the local session when the server call fails',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] and keeps the local session when the server call fails',
      );
      when(
        () => repository.logout(),
      ).thenThrow(const ApiException(message: 'Server unreachable'));
    },
    build: () => LogoutCubit(repository: repository),
    act: (cubit) => cubit.logout(),
    expect: () => [
      isA<LogoutLoading>(),
      isA<LogoutError>().having((s) => s.message, 'message', 'Server unreachable'),
    ],
    verify: (_) {
      // Unlike AuthCubit.logout (which swallows API errors and clears anyway),
      // this cubit surfaces the failure and leaves the session intact.
      printTestLog('isLoggedIn → expected: true, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    },
  );
}
