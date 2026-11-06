import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/auth/cubit/delete_account_cubit.dart';

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

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'emits [Loading, Loaded] and clears the local session on success',
    setUp: () {
      printTestDivider(
        'emits [Loading, Loaded] and clears the local session on success',
      );
      when(() => repository.deleteAccount()).thenAnswer((_) async {});
    },
    build: () => DeleteAccountCubit(repository: repository),
    act: (cubit) => cubit.deleteAccount(),
    expect: () => [isA<DeleteAccountLoading>(), isA<DeleteAccountLoaded>()],
    verify: (_) {
      printTestLog('isLoggedIn → expected: false, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    },
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'emits [Loading, Error] and keeps the local session when the call fails',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] and keeps the local session when the call fails',
      );
      when(
        () => repository.deleteAccount(),
      ).thenThrow(const ApiException(message: 'Cannot delete right now'));
    },
    build: () => DeleteAccountCubit(repository: repository),
    act: (cubit) => cubit.deleteAccount(),
    expect: () => [
      isA<DeleteAccountLoading>(),
      isA<DeleteAccountError>().having(
        (s) => s.message,
        'message',
        'Cannot delete right now',
      ),
    ],
    verify: (_) {
      printTestLog('isLoggedIn → expected: true, actual: ${AuthHiveBox.instance.isLoggedIn}');
      expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    },
  );
}
