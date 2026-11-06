import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;
  late AuthModel profile;

  setUp(() {
    repository = MockAuthRepository();
    // The profile endpoint returns the same envelope the login endpoint does,
    // so the auth fixture doubles as the profile payload.
    profile = AuthModel.fromJson(
      jsonDecode(File('test/fixtures/auth/login_response.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('starts in ProfileDetailInitial', () {
    printTestDivider('ProfileDetailCubit starts in ProfileDetailInitial');
    final cubit = ProfileDetailCubit(repository: repository);
    printTestLog(
      'initial state → expected: ProfileDetailInitial, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<ProfileDetailInitial>());
    cubit.close();
  });

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'loadProfile emits [Loading, Loaded] and re-parses the repository response',
    setUp: () {
      printTestDivider(
        'ProfileDetailCubit.loadProfile emits [Loading, Loaded] on success',
      );
      when(() => repository.getProfile()).thenAnswer((_) async => profile);
    },
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [isA<ProfileDetailLoading>(), isA<ProfileDetailLoaded>()],
    verify: (cubit) {
      verify(() => repository.getProfile()).called(1);
      final data = (cubit.state as ProfileDetailLoaded).data;
      printTestLog(
        'name → expected: "Alex Johnson", actual: "${data.data?.name}"',
      );
      expect(data.data?.name, 'Alex Johnson');
      printTestLog(
        'email → expected: "alex@gmail.com", actual: "${data.data?.email}"',
      );
      expect(data.data?.email, 'alex@gmail.com');
      // loadProfile round-trips the model through toJson/fromJson, so the
      // emitted model is a copy, never the repository's own instance.
      printTestLog(
        'emitted instance → expected: a copy, actual: identical=${identical(data, profile)}',
      );
      expect(identical(data, profile), isFalse);
    },
  );

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'loadProfile emits [Loading, Error] with the API message on ApiException',
    setUp: () {
      printTestDivider(
        'ProfileDetailCubit.loadProfile emits [Loading, Error] on ApiException',
      );
      when(
        () => repository.getProfile(),
      ).thenThrow(const ApiException(message: 'Profile unavailable'));
    },
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [isA<ProfileDetailLoading>(), isA<ProfileDetailError>()],
    verify: (cubit) {
      final message = (cubit.state as ProfileDetailError).message;
      printTestLog(
        'message → expected: "Profile unavailable", actual: "$message"',
      );
      expect(message, 'Profile unavailable');
    },
  );

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'loadProfile emits [Loading, Error] with the generic message on an unexpected error',
    setUp: () {
      printTestDivider(
        'ProfileDetailCubit.loadProfile emits [Loading, Error] on a non-API error',
      );
      when(() => repository.getProfile()).thenThrow(Exception('socket closed'));
    },
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [isA<ProfileDetailLoading>(), isA<ProfileDetailError>()],
    verify: (cubit) {
      // Translations aren't loaded under `flutter test`, so the localized
      // generic message comes back as its raw key.
      final message = (cubit.state as ProfileDetailError).message;
      printTestLog(
        'message → expected: "something_went_wrong", actual: "$message"',
      );
      expect(message, 'something_went_wrong');
    },
  );

  blocTest<ProfileDetailCubit, ProfileDetailState>(
    'setProfile emits Loaded without touching the repository',
    setUp: () => printTestDivider(
      'ProfileDetailCubit.setProfile emits Loaded without an API call',
    ),
    build: () => ProfileDetailCubit(repository: repository),
    act: (cubit) => cubit.setProfile(profile),
    expect: () => [isA<ProfileDetailLoaded>()],
    verify: (cubit) {
      verifyNever(() => repository.getProfile());
      final data = (cubit.state as ProfileDetailLoaded).data;
      printTestLog(
        'emitted instance → expected: the passed model, actual: identical=${identical(data, profile)}',
      );
      expect(identical(data, profile), isTrue);
    },
  );
}
