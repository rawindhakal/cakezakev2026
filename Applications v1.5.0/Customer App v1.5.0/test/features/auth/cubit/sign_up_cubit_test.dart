import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/models/auth_model.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

/// `SignUpCubit.signUp()` only calls `AnalyticsService.instance.logEvent(...)`
/// on the branch where the response carries a non-empty `access_token` (i.e.
/// full auto-login on signup) — that singleton lazily constructs a real
/// `FirebaseAnalytics.instance`, which throws synchronously under
/// `flutter test` with no Firebase app initialized (no mock-channel seam
/// exists for it yet). Its non-ApiException `catch` block hits the same wall
/// via `CrashlyticsService.instance.recordError`. Both branches are therefore
/// left uncovered here rather than faked around — see TESTING.md's gotchas
/// section. Every other branch (the token-less "email OTP required" success
/// path, and both cubit methods that never touch Analytics/Crashlytics at
/// all) is fully covered below.
void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is SignUpInitial', () {
    printTestDivider('SignUpCubit initial state is SignUpInitial');
    final cubit = SignUpCubit(repository: repository);

    expect(cubit.state, isA<SignUpInitial>());
    cubit.close();
  });

  group('signUp', () {
    blocTest<SignUpCubit, SignUpState>(
      'emits Loaded (no auth attached) when the response has no access token, e.g. email verification pending',
      setUp: () {
        when(
          () => repository.signUp(
            name: 'Jordan',
            mobile: any(named: 'mobile'),
            password: any(named: 'password'),
            type: any(named: 'type'),
            email: any(named: 'email'),
            profileImagePath: any(named: 'profileImagePath'),
            friendsCode: any(named: 'friendsCode'),
            phoneAuthType: any(named: 'phoneAuthType'),
            languageId: any(named: 'languageId'),
            countryCode: any(named: 'countryCode'),
            countryId: any(named: 'countryId'),
          ),
        ).thenAnswer((_) async => AuthModel(message: 'Check your email'));
      },
      build: () => SignUpCubit(repository: repository),
      act: (cubit) => cubit.signUp(name: 'Jordan', email: 'a@b.com'),
      expect: () => [
        isA<SignUpLoading>(),
        isA<SignUpLoaded>()
            .having((s) => s.message, 'message', 'Check your email')
            .having((s) => s.auth, 'auth', isNull),
      ],
    );

    blocTest<SignUpCubit, SignUpState>(
      'surfaces the ApiException message on failure (e.g. duplicate email)',
      setUp: () {
        when(
          () => repository.signUp(
            name: 'Jordan',
            mobile: any(named: 'mobile'),
            password: any(named: 'password'),
            type: any(named: 'type'),
            email: any(named: 'email'),
            profileImagePath: any(named: 'profileImagePath'),
            friendsCode: any(named: 'friendsCode'),
            phoneAuthType: any(named: 'phoneAuthType'),
            languageId: any(named: 'languageId'),
            countryCode: any(named: 'countryCode'),
            countryId: any(named: 'countryId'),
          ),
        ).thenThrow(const ApiException(message: 'Email already registered'));
      },
      build: () => SignUpCubit(repository: repository),
      act: (cubit) => cubit.signUp(name: 'Jordan', email: 'a@b.com'),
      expect: () => [
        isA<SignUpLoading>(),
        isA<SignUpError>().having(
          (s) => s.message,
          'message',
          'Email already registered',
        ),
      ],
    );
  });

  group('signUpWithEmail', () {
    blocTest<SignUpCubit, SignUpState>(
      'emits EmailOtpRequired with the api message on success (never auto-logs in)',
      setUp: () {
        when(
          () => repository.signUp(
            name: 'Jordan',
            email: 'a@b.com',
            password: 'Passw0rd!',
            mobile: any(named: 'mobile'),
            countryCode: any(named: 'countryCode'),
            countryId: any(named: 'countryId'),
            type: 'email',
            phoneAuthType: 'password',
            friendsCode: any(named: 'friendsCode'),
            languageId: any(named: 'languageId'),
          ),
        ).thenAnswer((_) async => AuthModel(message: 'OTP sent to your email'));
      },
      build: () => SignUpCubit(repository: repository),
      act: (cubit) => cubit.signUpWithEmail(
        name: 'Jordan',
        email: 'a@b.com',
        password: 'Passw0rd!',
      ),
      expect: () => [
        isA<SignUpLoading>(),
        isA<SignUpEmailOtpRequired>().having(
          (s) => s.message,
          'message',
          'OTP sent to your email',
        ),
      ],
    );

    blocTest<SignUpCubit, SignUpState>(
      'surfaces the ApiException message on failure',
      setUp: () {
        when(
          () => repository.signUp(
            name: 'Jordan',
            email: 'a@b.com',
            password: 'Passw0rd!',
            mobile: any(named: 'mobile'),
            countryCode: any(named: 'countryCode'),
            countryId: any(named: 'countryId'),
            type: 'email',
            phoneAuthType: 'password',
            friendsCode: any(named: 'friendsCode'),
            languageId: any(named: 'languageId'),
          ),
        ).thenThrow(const ApiException(message: 'Weak password'));
      },
      build: () => SignUpCubit(repository: repository),
      act: (cubit) => cubit.signUpWithEmail(
        name: 'Jordan',
        email: 'a@b.com',
        password: 'Passw0rd!',
      ),
      expect: () => [
        isA<SignUpLoading>(),
        isA<SignUpError>().having((s) => s.message, 'message', 'Weak password'),
      ],
    );
  });

  group('sendPhoneOtpForSignUp', () {
    blocTest<SignUpCubit, SignUpState>(
      'emits PhoneOtpSent with the firebase verificationId on success',
      setUp: () {
        when(
          () => repository.sendPhoneOtpAndGetVerificationId(
            phoneNumber: '5551234567',
            countryCode: '+1',
          ),
        ).thenAnswer((_) async => 'vid-99');
      },
      build: () => SignUpCubit(repository: repository),
      act: (cubit) => cubit.sendPhoneOtpForSignUp(
        phoneNumber: '5551234567',
        countryCode: '+1',
      ),
      expect: () => [
        isA<SignUpLoading>(),
        isA<SignUpPhoneOtpSent>().having(
          (s) => s.verificationId,
          'verificationId',
          'vid-99',
        ),
      ],
    );

    blocTest<SignUpCubit, SignUpState>(
      'surfaces the ApiException message on failure',
      setUp: () {
        when(
          () => repository.sendPhoneOtpAndGetVerificationId(
            phoneNumber: '5551234567',
            countryCode: '+1',
          ),
        ).thenThrow(const ApiException(message: 'Invalid phone number'));
      },
      build: () => SignUpCubit(repository: repository),
      act: (cubit) => cubit.sendPhoneOtpForSignUp(
        phoneNumber: '5551234567',
        countryCode: '+1',
      ),
      expect: () => [
        isA<SignUpLoading>(),
        isA<SignUpError>().having(
          (s) => s.message,
          'message',
          'Invalid phone number',
        ),
      ],
    );
  });

  blocTest<SignUpCubit, SignUpState>(
    'reset() returns to Initial',
    build: () => SignUpCubit(repository: repository),
    act: (cubit) => cubit.reset(),
    expect: () => [isA<SignUpInitial>()],
  );
}
