import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/forgot_password_cubit.dart';
import 'package:customer/features/auth/screens/forgot_password_screen.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// `showForgotPasswordSheet` normally builds its own `ForgotPasswordCubit()`
/// inline (`BlocProvider(create: (_) => ForgotPasswordCubit())`), which —
/// via `AuthRepository()`'s default constructor — touches
/// `FirebaseAuth.instance` eagerly, before any OTP method is ever called.
/// That throws under `flutter test` (confirmed by first attempting this file
/// without the seam below: the sheet crashed on its very first build, before
/// any assertion could even run, since `BlocConsumer<ForgotPasswordCubit,_>`
/// reads the cubit in `initState`). `showForgotPasswordSheet` gained a
/// `@visibleForTesting ForgotPasswordCubit? cubit` parameter (mirrors
/// `ApiClient.httpClientAdapter`'s existing test-only seam) so this file can
/// supply a `MockForgotPasswordCubit` instead — the only way to widget-test
/// this screen at all. `CountriesCubit`/`SettingsCubit` are read directly via
/// `context.read` (`initState`, and `_isFirebase`) — both must be provided,
/// and above `MaterialApp` itself, not just its `home`: a modal bottom sheet
/// is pushed as a *sibling* route on the same `Navigator`, not as a
/// descendant of the route that opened it, so a `BlocProvider` placed only
/// around `home` is invisible to the sheet's content.
void main() {
  late MockSettingsCubit settingsCubit;
  late MockCountriesCubit countriesCubit;
  late MockForgotPasswordCubit forgotPasswordCubit;

  Widget buildHarness(String type) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<CountriesCubit>.value(value: countriesCubit),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showForgotPasswordSheet(
                context,
                type: type,
                cubit: forgotPasswordCubit,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  setUpAll(() => HiveTestHelper.setUp(settingsBox));
  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  setUp(() {
    settingsCubit = MockSettingsCubit();
    countriesCubit = MockCountriesCubit();
    forgotPasswordCubit = MockForgotPasswordCubit();

    when(() => settingsCubit.state).thenReturn(
      SettingsLoaded(AppSettings(data: AppSettingsData(firebaseAuthentication: '0'))),
    );
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => countriesCubit.state).thenReturn(CountriesInitial());
    when(() => countriesCubit.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => forgotPasswordCubit.state)
        .thenReturn(ForgotPasswordInitial());
    when(() => forgotPasswordCubit.stream)
        .thenAnswer((_) => const Stream.empty());
  });

  testWidgets('phone type shows the phone field and the phone-specific subtitle', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordScreen phone type shows the phone field and the phone-specific subtitle',
    );
    await tester.pumpWidget(buildHarness(AuthType.phone.name));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    printTestLog(
      'title → expected: present, actual: ${find.text(LanguageLabelKeys.forgotPassword).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.forgotPassword), findsOneWidget);
    printTestLog(
      'phone subtitle → expected: present, actual: ${find.textContaining(LanguageLabelKeys.enterRegisteredPhoneNumber).evaluate().isNotEmpty}',
    );
    expect(find.textContaining(LanguageLabelKeys.enterRegisteredPhoneNumber), findsOneWidget);
    printTestLog(
      'phone field label → expected: present, actual: ${find.text(LanguageLabelKeys.phoneNumber).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.phoneNumber), findsOneWidget);
    printTestLog(
      'email field label → expected: absent, actual: ${find.text(LanguageLabelKeys.email).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.email), findsNothing);
  });

  testWidgets('email type shows the email field and the email-specific subtitle', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordScreen email type shows the email field and the email-specific subtitle',
    );
    await tester.pumpWidget(buildHarness(AuthType.email.name));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    printTestLog(
      'email subtitle → expected: present, actual: ${find.textContaining(LanguageLabelKeys.enterRegisteredEmailAddress).evaluate().isNotEmpty}',
    );
    expect(find.textContaining(LanguageLabelKeys.enterRegisteredEmailAddress), findsOneWidget);
    printTestLog(
      'email field label → expected: present, actual: ${find.text(LanguageLabelKeys.email).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.email), findsOneWidget);
    printTestLog(
      'phone field label → expected: absent, actual: ${find.text(LanguageLabelKeys.phoneNumber).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.phoneNumber), findsNothing);
  });

  testWidgets(
    'submitting a valid phone number calls ForgotPasswordCubit.verifyPhoneAndSendOtp',
    (tester) async {
      printTestDivider(
        'ForgotPasswordScreen submitting a valid phone number calls ForgotPasswordCubit.verifyPhoneAndSendOtp',
      );
      when(
        () => forgotPasswordCubit.verifyPhoneAndSendOtp(
          mobile: any(named: 'mobile'),
          countryCode: any(named: 'countryCode'),
          isFirebase: any(named: 'isFirebase'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildHarness(AuthType.phone.name));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '9998887776');
      await tester.tap(find.text(LanguageLabelKeys.sendOtp, findRichText: true));
      await tester.pump();

      final captured = verify(
        () => forgotPasswordCubit.verifyPhoneAndSendOtp(
          mobile: captureAny(named: 'mobile'),
          countryCode: any(named: 'countryCode'),
          isFirebase: captureAny(named: 'isFirebase'),
        ),
      ).captured;
      printTestLog('mobile → expected: "9998887776", actual: "${captured[0]}"');
      expect(captured[0], '9998887776');
      printTestLog('isFirebase → expected: false, actual: ${captured[1]}');
      expect(captured[1], isFalse);
    },
  );

  testWidgets(
    'submitting a valid email calls ForgotPasswordCubit.sendEmailOtp',
    (tester) async {
      printTestDivider(
        'ForgotPasswordScreen submitting a valid email calls ForgotPasswordCubit.sendEmailOtp',
      );
      when(
        () => forgotPasswordCubit.sendEmailOtp(email: any(named: 'email')),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildHarness(AuthType.email.name));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'jordan@example.com');
      await tester.tap(find.text(LanguageLabelKeys.sendOtp, findRichText: true));
      await tester.pump();

      final captured = verify(
        () => forgotPasswordCubit.sendEmailOtp(email: captureAny(named: 'email')),
      ).captured;
      printTestLog('email → expected: "jordan@example.com", actual: "${captured[0]}"');
      expect(captured[0], 'jordan@example.com');
    },
  );

  testWidgets('a ForgotPasswordOtpSent state moves phase 0 to the OTP phase', (tester) async {
    printTestDivider(
      'ForgotPasswordScreen a ForgotPasswordOtpSent state moves phase 0 to the OTP phase',
    );
    whenListen<ForgotPasswordState>(
      forgotPasswordCubit,
      Stream.fromIterable([ForgotPasswordOtpSent()]),
      initialState: ForgotPasswordInitial(),
    );

    await tester.pumpWidget(buildHarness(AuthType.email.name));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    printTestLog(
      'OTP field → expected: present, actual: ${find.byType(Pinput).evaluate().isNotEmpty}',
    );
    expect(find.byType(Pinput), findsOneWidget);
    printTestLog(
      'code-sent subtitle → expected: present, actual: ${find.textContaining(LanguageLabelKeys.codeSentTo).evaluate().isNotEmpty}',
    );
    expect(find.textContaining(LanguageLabelKeys.codeSentTo), findsOneWidget);
  });

  testWidgets('a ForgotPasswordError state shows the message in a snackbar', (tester) async {
    printTestDivider(
      'ForgotPasswordScreen a ForgotPasswordError state shows the message in a snackbar',
    );
    whenListen<ForgotPasswordState>(
      forgotPasswordCubit,
      Stream.fromIterable([ForgotPasswordError('User not found')]),
      initialState: ForgotPasswordInitial(),
    );

    await tester.pumpWidget(buildHarness(AuthType.email.name));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    printTestLog(
      'snackbar message → expected: present, actual: ${find.text('User not found').evaluate().isNotEmpty}',
    );
    expect(find.text('User not found'), findsOneWidget);
  });
}
