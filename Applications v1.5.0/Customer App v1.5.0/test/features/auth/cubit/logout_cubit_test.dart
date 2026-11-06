import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/cubits/logout_cubit.dart';
import 'package:customer/features/auth/models/auth_model.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

/// `LogoutCubit` duplicates `AuthCubit.logout()`'s effect (clear local
/// session) but, unlike `AuthCubit`, propagates the api error as a state
/// instead of swallowing it — the two cubits back different UI surfaces
/// (in-app logout button vs. the app-level auth gate) and are covered
/// separately since their failure behavior genuinely differs.
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

  test('initial state is LogoutInitial', () {
    printTestDivider('LogoutCubit initial state is LogoutInitial');
    final cubit = LogoutCubit(repository: repository);

    expect(cubit.state, isA<LogoutInitial>());
    cubit.close();
  });

  blocTest<LogoutCubit, LogoutState>(
    'emits Loading then Loaded and clears the local session on success',
    setUp: () {
      when(() => repository.logout()).thenAnswer((_) async {});
    },
    build: () => LogoutCubit(repository: repository),
    act: (cubit) => cubit.logout(),
    expect: () => [isA<LogoutLoading>(), isA<LogoutLoaded>()],
    verify: (_) {
      printTestLog(
        'token after logout → expected: null/empty, actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken() ?? '', isEmpty);
    },
  );

  blocTest<LogoutCubit, LogoutState>(
    'surfaces the ApiException message and leaves the session untouched on failure',
    setUp: () {
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
      printTestLog(
        'token after failed logout → expected: "tok" (untouched), actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken(), 'tok');
    },
  );
}
