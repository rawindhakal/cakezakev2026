import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

class MockUserCredential extends Mock implements UserCredential {}

/// A *successful* `SignInCubit` login (`SignInLoaded`) routes through
/// `_onLoginSuccess`, which calls `AnalyticsService.instance.logEvent(...)`
/// — a singleton that lazily constructs a real `FirebaseAnalytics.instance`
/// and throws synchronously under `flutter test` (no Firebase app
/// initialized, no mock-channel seam built for it). The same is true of
/// every method's non-`ApiException` `catch` branch, which calls
/// `CrashlyticsService.instance.recordError`. Both are left uncovered here
/// rather than faked around with a partial Firebase mock — see TESTING.md's
/// gotchas section for the full writeup. Every `ApiException`-driven branch
/// below (`SignInError`, `SignInUserNotFound`, `SignInCancelled`) runs
/// entirely inside `on ApiException catch (e)`, before either singleton is
/// ever touched, so those are fully covered — as is `sendPhoneOtp`, which
/// never calls either service on any branch.
void main() {
  late MockAuthRepository repository;

  setUp(() async {
    repository = MockAuthRepository();
    await HiveTestHelper.setUp(authBox);
  });

  tearDown(() => HiveTestHelper.tearDown(authBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is SignInInitial', () {
    printTestDivider('SignInCubit initial state is SignInInitial');
    final cubit = SignInCubit(repository: repository);

    expect(cubit.state, isA<SignInInitial>());
    cubit.close();
  });

  group('verifyPhoneOtp', () {
    blocTest<SignInCubit, SignInState>(
      'emits UserNotFound (not a generic error) when the backend reports USER_NOT_FOUND',
      setUp: () {
        when(
          () => repository.verifyPhoneOtp(
            phoneNumber: '5551234567',
            type: 'phone',
            phoneAuthType: 'phone_auth_otp',
            languageId: any(named: 'languageId'),
            countryCode: '+1',
          ),
        ).thenThrow(
          const ApiException(
            message: 'No account found',
            messageStatusCode: 'USER_NOT_FOUND',
          ),
        );
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneOtp(
        phoneNumber: '5551234567',
        type: 'phone',
        phoneAuthType: 'phone_auth_otp',
        countryCode: '+1',
      ),
      expect: () => [
        isA<SignInLoading>(),
        isA<SignInUserNotFound>().having((s) => s.phone, 'phone', '5551234567'),
      ],
    );

    blocTest<SignInCubit, SignInState>(
      'emits a generic SignInError for any other ApiException',
      setUp: () {
        when(
          () => repository.verifyPhoneOtp(
            phoneNumber: '5551234567',
            type: 'phone',
            phoneAuthType: 'phone_auth_otp',
            languageId: any(named: 'languageId'),
            countryCode: '+1',
          ),
        ).thenThrow(const ApiException(message: 'OTP expired'));
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.verifyPhoneOtp(
        phoneNumber: '5551234567',
        type: 'phone',
        phoneAuthType: 'phone_auth_otp',
        countryCode: '+1',
      ),
      expect: () => [
        isA<SignInLoading>(),
        isA<SignInError>().having((s) => s.message, 'message', 'OTP expired'),
      ],
    );
  });

  group('loginWithPhonePassword', () {
    blocTest<SignInCubit, SignInState>(
      'emits UserNotFound when the backend reports USER_NOT_EXIST',
      setUp: () {
        when(
          () => repository.loginWithPhonePassword(
            id: '5551234567',
            password: 'secret',
            type: 'phone',
            phoneAuthType: 'phone_auth_password',
            countryCode: '+1',
            languageId: any(named: 'languageId'),
          ),
        ).thenThrow(
          const ApiException(
            message: 'No account',
            messageStatusCode: 'USER_NOT_EXIST',
          ),
        );
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.loginWithPhonePassword(
        id: '5551234567',
        password: 'secret',
        type: 'phone',
        phoneAuthType: 'phone_auth_password',
        countryCode: '+1',
      ),
      expect: () => [
        isA<SignInLoading>(),
        isA<SignInUserNotFound>().having((s) => s.phone, 'phone', '5551234567'),
      ],
    );
  });

  group('loginWithEmailPassword', () {
    blocTest<SignInCubit, SignInState>(
      'emits SignInError (never UserNotFound — that branch is commented out for email)',
      setUp: () {
        when(
          () => repository.loginWithEmailPassword(
            id: 'a@b.com',
            password: 'secret',
            type: 'email',
            languageId: any(named: 'languageId'),
          ),
        ).thenThrow(
          const ApiException(
            message: 'No account',
            messageStatusCode: 'USER_NOT_EXIST',
          ),
        );
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.loginWithEmailPassword(
        id: 'a@b.com',
        password: 'secret',
        type: 'email',
      ),
      expect: () => [
        isA<SignInLoading>(),
        isA<SignInError>().having((s) => s.message, 'message', 'No account'),
      ],
    );
  });

  group('loginWithGoogle / loginWithApple', () {
    blocTest<SignInCubit, SignInState>(
      'loginWithGoogle emits Cancelled when the api reports isCancelled',
      setUp: () {
        final credential = MockUserCredential();
        when(() => credential.user).thenReturn(null);
        when(
          () => repository.signInWithGoogleFirebase(),
        ).thenAnswer((_) async => credential);
        when(
          () => repository.loginWithGoogle(
            type: 'google',
            languageId: any(named: 'languageId'),
            preAuthEmail: any(named: 'preAuthEmail'),
          ),
        ).thenThrow(const ApiException(message: '', isCancelled: true));
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.loginWithGoogle(type: 'google'),
      expect: () => [isA<SignInLoading>(), isA<SignInCancelled>()],
    );

    blocTest<SignInCubit, SignInState>(
      'loginWithGoogle emits UserNotFound with provider "google" when the backend reports it',
      setUp: () {
        final credential = MockUserCredential();
        when(() => credential.user).thenReturn(null);
        when(
          () => repository.signInWithGoogleFirebase(),
        ).thenAnswer((_) async => credential);
        when(
          () => repository.loginWithGoogle(
            type: 'google',
            languageId: any(named: 'languageId'),
            preAuthEmail: any(named: 'preAuthEmail'),
          ),
        ).thenThrow(
          const ApiException(
            message: 'No account',
            messageStatusCode: 'USER_NOT_FOUND',
          ),
        );
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.loginWithGoogle(type: 'google'),
      expect: () => [
        isA<SignInLoading>(),
        isA<SignInUserNotFound>().having((s) => s.provider, 'provider', 'google'),
      ],
    );

    blocTest<SignInCubit, SignInState>(
      'loginWithApple emits Cancelled when the api reports isCancelled',
      setUp: () {
        final credential = MockUserCredential();
        when(() => credential.user).thenReturn(null);
        when(
          () => repository.signInWithAppleFirebase(),
        ).thenAnswer((_) async => credential);
        when(
          () => repository.loginWithApple(
            type: 'apple',
            languageId: any(named: 'languageId'),
            preAuthEmail: any(named: 'preAuthEmail'),
          ),
        ).thenThrow(const ApiException(message: '', isCancelled: true));
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.loginWithApple(type: 'apple'),
      expect: () => [isA<SignInLoading>(), isA<SignInCancelled>()],
    );
  });

  group('sendPhoneOtp', () {
    blocTest<SignInCubit, SignInState>(
      'emits Loading then back to Initial on success (no persisted state of its own)',
      setUp: () {
        when(
          () => repository.sendPhoneOtp(
            phoneNumber: '5551234567',
            countryCode: '+1',
          ),
        ).thenAnswer((_) async {});
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.sendPhoneOtp(
        phoneNumber: '5551234567',
        countryCode: '+1',
      ),
      expect: () => [isA<SignInLoading>(), isA<SignInInitial>()],
    );

    blocTest<SignInCubit, SignInState>(
      'surfaces the ApiException message on failure',
      setUp: () {
        when(
          () => repository.sendPhoneOtp(
            phoneNumber: '5551234567',
            countryCode: '+1',
          ),
        ).thenThrow(const ApiException(message: 'Invalid number'));
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.sendPhoneOtp(
        phoneNumber: '5551234567',
        countryCode: '+1',
      ),
      expect: () => [
        isA<SignInLoading>(),
        isA<SignInError>().having((s) => s.message, 'message', 'Invalid number'),
      ],
    );

    blocTest<SignInCubit, SignInState>(
      'emits the generic error message on a non-ApiException error (no Crashlytics call on this path)',
      setUp: () {
        when(
          () => repository.sendPhoneOtp(
            phoneNumber: '5551234567',
            countryCode: '+1',
          ),
        ).thenThrow(Exception('boom'));
      },
      build: () => SignInCubit(repository: repository),
      act: (cubit) => cubit.sendPhoneOtp(
        phoneNumber: '5551234567',
        countryCode: '+1',
      ),
      expect: () => [isA<SignInLoading>(), isA<SignInError>()],
    );
  });

  blocTest<SignInCubit, SignInState>(
    'reset() returns to Initial',
    build: () => SignInCubit(repository: repository),
    act: (cubit) => cubit.reset(),
    expect: () => [isA<SignInInitial>()],
  );
}
