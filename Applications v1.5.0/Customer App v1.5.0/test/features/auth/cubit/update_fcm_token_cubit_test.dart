import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/cubits/update_fcm_token_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is UpdateFcmTokenInitial', () {
    printTestDivider('UpdateFcmTokenCubit initial state is UpdateFcmTokenInitial');
    final cubit = UpdateFcmTokenCubit(repository: repository);

    expect(cubit.state, isA<UpdateFcmTokenInitial>());
    cubit.close();
  });

  blocTest<UpdateFcmTokenCubit, UpdateFcmTokenState>(
    'emits Loading then Loaded on success',
    setUp: () {
      when(
        () => repository.updateFcmToken(
          fcmToken: 'tok',
          platform: 'ios',
          languageId: '1',
        ),
      ).thenAnswer((_) async {});
    },
    build: () => UpdateFcmTokenCubit(repository: repository),
    act: (cubit) => cubit.updateFcmToken(
      fcmToken: 'tok',
      platform: 'ios',
      languageId: '1',
    ),
    expect: () => [isA<UpdateFcmTokenLoading>(), isA<UpdateFcmTokenLoaded>()],
  );

  blocTest<UpdateFcmTokenCubit, UpdateFcmTokenState>(
    'surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.updateFcmToken(
          fcmToken: 'tok',
          platform: 'ios',
          languageId: '1',
        ),
      ).thenThrow(const ApiException(message: 'Update failed'));
    },
    build: () => UpdateFcmTokenCubit(repository: repository),
    act: (cubit) => cubit.updateFcmToken(
      fcmToken: 'tok',
      platform: 'ios',
      languageId: '1',
    ),
    expect: () => [
      isA<UpdateFcmTokenLoading>(),
      isA<UpdateFcmTokenError>().having((s) => s.message, 'message', 'Update failed'),
    ],
  );
}
