import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/models/auth_model.dart';
import 'package:customer/features/profile/cubit/profile_detail_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is ProfileDetailInitial', () {
    printTestDivider('ProfileDetailCubit initial state is ProfileDetailInitial');
    final cubit = ProfileDetailCubit(repository: repository);

    expect(cubit.state, isA<ProfileDetailInitial>());
    cubit.close();
  });

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'emits Loading then Loaded with the fetched profile on success',
    setUp: () {
      when(() => repository.getProfile()).thenAnswer(
        (_) async => AuthModel(
          data: AuthModelData(
            id: 42,
            name: 'Jordan Blake',
            email: 'jordan.blake@example.com',
            balance: 125.5,
          ),
        ),
      );
    },
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [
      isA<ProfileDetailLoading>(),
      isA<ProfileDetailLoaded>().having(
        (s) => s.profile.data?.email,
        'profile.data.email',
        'jordan.blake@example.com',
      ),
    ],
  );

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.getProfile(),
      ).thenThrow(const ApiException(message: 'Profile fetch failed'));
    },
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [
      isA<ProfileDetailLoading>(),
      isA<ProfileDetailError>().having(
        (s) => s.message,
        'message',
        'Profile fetch failed',
      ),
    ],
  );

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'emits a generic error message for a non-ApiException failure',
    setUp: () {
      when(() => repository.getProfile()).thenThrow(Exception('boom'));
    },
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [isA<ProfileDetailLoading>(), isA<ProfileDetailError>()],
    verify: (cubit) {
      final message = (cubit.state as ProfileDetailError).message;
      printTestLog(
        'generic error message → expected: non-empty, actual: "$message"',
      );
      expect(message, isNotEmpty);
    },
  );
}
