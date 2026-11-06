import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/cubits/add_fcm_token_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is AddFcmTokenInitial', () {
    printTestDivider('AddFcmTokenCubit initial state is AddFcmTokenInitial');
    final cubit = AddFcmTokenCubit(repository: repository);

    expect(cubit.state, isA<AddFcmTokenInitial>());
    cubit.close();
  });

  blocTest<AddFcmTokenCubit, AddFcmTokenState>(
    'emits Loading then Loaded on success',
    setUp: () {
      when(
        () => repository.addFcmToken(fcmToken: 'tok', platform: 'android'),
      ).thenAnswer((_) async {});
    },
    build: () => AddFcmTokenCubit(repository: repository),
    act: (cubit) => cubit.addFcmToken(fcmToken: 'tok', platform: 'android'),
    expect: () => [isA<AddFcmTokenLoading>(), isA<AddFcmTokenLoaded>()],
  );

  blocTest<AddFcmTokenCubit, AddFcmTokenState>(
    'surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.addFcmToken(fcmToken: 'tok', platform: 'android'),
      ).thenThrow(const ApiException(message: 'Server unavailable'));
    },
    build: () => AddFcmTokenCubit(repository: repository),
    act: (cubit) => cubit.addFcmToken(fcmToken: 'tok', platform: 'android'),
    expect: () => [
      isA<AddFcmTokenLoading>(),
      isA<AddFcmTokenError>().having((s) => s.message, 'message', 'Server unavailable'),
    ],
  );

  blocTest<AddFcmTokenCubit, AddFcmTokenState>(
    'emits the generic error message on a non-ApiException error',
    setUp: () {
      when(
        () => repository.addFcmToken(fcmToken: 'tok', platform: 'android'),
      ).thenThrow(Exception('boom'));
    },
    build: () => AddFcmTokenCubit(repository: repository),
    act: (cubit) => cubit.addFcmToken(fcmToken: 'tok', platform: 'android'),
    expect: () => [isA<AddFcmTokenLoading>(), isA<AddFcmTokenError>()],
  );
}
