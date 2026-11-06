import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/cubits/delete_account_cubit.dart';
import 'package:customer/features/auth/models/auth_model.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() async {
    repository = MockAuthRepository();
    await HiveTestHelper.setUp(authBox);
    await AuthHiveBox.instance.saveLoginData(
      userLogin: AuthModel(data: AuthModelData(accessToken: 'tok')),
    );
  });

  tearDown(() => HiveTestHelper.tearDown(authBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is DeleteAccountInitial', () {
    printTestDivider('DeleteAccountCubit initial state is DeleteAccountInitial');
    final cubit = DeleteAccountCubit(repository: repository);

    expect(cubit.state, isA<DeleteAccountInitial>());
    cubit.close();
  });

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'emits Loading then Loaded and clears the local session on success',
    setUp: () {
      when(() => repository.deleteAccount()).thenAnswer((_) async {});
    },
    build: () => DeleteAccountCubit(repository: repository),
    act: (cubit) => cubit.deleteAccount(),
    expect: () => [isA<DeleteAccountLoading>(), isA<DeleteAccountLoaded>()],
    verify: (_) {
      printTestLog(
        'token after delete → expected: null/empty, actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken() ?? '', isEmpty);
    },
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'surfaces the ApiException message and leaves the session untouched on failure',
    setUp: () {
      when(
        () => repository.deleteAccount(),
      ).thenThrow(const ApiException(message: 'Delete failed'));
    },
    build: () => DeleteAccountCubit(repository: repository),
    act: (cubit) => cubit.deleteAccount(),
    expect: () => [
      isA<DeleteAccountLoading>(),
      isA<DeleteAccountError>().having((s) => s.message, 'message', 'Delete failed'),
    ],
    verify: (_) {
      printTestLog(
        'token after failed delete → expected: "tok" (untouched), actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken(), 'tok');
    },
  );
}
