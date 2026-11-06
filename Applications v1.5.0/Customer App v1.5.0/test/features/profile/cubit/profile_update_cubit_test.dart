import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/profile/cubit/profile_update_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

/// A *successful* `ProfileUpdateCubit.updateProfile` call routes through
/// `AnalyticsService.instance.logEvent(...)` right before `emit(Loaded)` —
/// a singleton that lazily constructs a real `FirebaseAnalytics.instance`
/// and throws synchronously under `flutter test` (no Firebase app
/// initialized). That throw lands inside the method's own outer
/// `try`/`catch`, which then calls `CrashlyticsService.instance.recordError`
/// — a second Firebase singleton that throws the same way, this time with
/// nothing left to catch it, so it escapes the cubit method entirely. Both
/// the `Loaded` success path and the generic (non-`ApiException`) `catch`
/// branch are therefore untestable here, the same class of gotcha
/// `SignInCubit`'s `SignInLoaded` path documents (see TESTING.md). Only the
/// `on ApiException catch (e)` branch runs before either singleton is ever
/// touched, so that's the one case covered below.
void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is ProfileUpdateInitial', () {
    printTestDivider('ProfileUpdateCubit initial state is ProfileUpdateInitial');
    final cubit = ProfileUpdateCubit(repository: repository);

    expect(cubit.state, isA<ProfileUpdateInitial>());
    cubit.close();
  });

  blocTest<ProfileUpdateCubit, ProfileUpdateState>(
    'emits Loading then surfaces the ApiException message on failure, '
    'before either Analytics or Crashlytics is ever touched',
    setUp: () {
      when(
        () => repository.updateProfile(
          name: any(named: 'name'),
          mobile: any(named: 'mobile'),
          email: any(named: 'email'),
          profileImagePath: any(named: 'profileImagePath'),
          countryId: any(named: 'countryId'),
          countryCode: any(named: 'countryCode'),
        ),
      ).thenThrow(const ApiException(message: 'Update failed'));
    },
    build: () => ProfileUpdateCubit(repository: repository),
    act: (cubit) => cubit.updateProfile(name: 'Jordan Blake'),
    expect: () => [
      isA<ProfileUpdateLoading>(),
      isA<ProfileUpdateError>().having(
        (s) => s.message,
        'message',
        'Update failed',
      ),
    ],
    verify: (_) {
      printTestLog(
        'repository.updateProfile called with name → expected: "Jordan Blake"',
      );
      verify(
        () => repository.updateProfile(
          name: 'Jordan Blake',
          mobile: null,
          email: null,
          profileImagePath: null,
          countryId: null,
          countryCode: null,
        ),
      ).called(1);
    },
  );
}
