import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';
import 'package:customer/features/auth/screens/sign_in_screen.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// `SignInScreen` reads three cubits via `context.read`/`BlocBuilder`
/// (`SettingsCubit`, `SignInCubit`, `CustomSmsSendPhoneOtpCubit`) plus a
/// fourth (`CountriesCubit`) purely for its `BlocListener` — all four must be
/// provided, unlike faq/blog's single-cubit screens. `AuthTermsBar` also
/// reads `context.bottomSafePadding`, which just needs a real `MediaQuery`
/// (provided free by `MaterialApp`), and `_buildSkipButton`'s `onPressed`
/// reads `SettingsHiveBox.instance.hasLocation`, so the settings box must be
/// open even though this suite never taps Skip.
void main() {
  late MockSettingsCubit settingsCubit;
  late MockSignInCubit signInCubit;
  late MockCustomSmsSendPhoneOtpCubit customSmsCubit;
  late MockCountriesCubit countriesCubit;

  AppSettingsData settingsData({
    String emailLogin = '1',
    String phoneLogin = '1',
    String googleLogin = '0',
    String appleLogin = '0',
  }) => AppSettingsData(
    emailLogin: emailLogin,
    phoneLogin: phoneLogin,
    googleLogin: googleLogin,
    appleLogin: appleLogin,
    firebaseAuthentication: '0',
    customSmsGatewayOtpBased: '0',
    phoneAuthPassword: '0',
  );

  Widget buildScreen() {
    return MaterialApp(
      theme: ThemeData.light(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<SignInCubit>.value(value: signInCubit),
          BlocProvider<CustomSmsSendPhoneOtpCubit>.value(value: customSmsCubit),
          BlocProvider<CountriesCubit>.value(value: countriesCubit),
        ],
        child: const SignInScreen(),
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
    signInCubit = MockSignInCubit();
    customSmsCubit = MockCustomSmsSendPhoneOtpCubit();
    countriesCubit = MockCountriesCubit();

    when(() => countriesCubit.state).thenReturn(CountriesInitial());
    when(() => countriesCubit.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => signInCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => customSmsCubit.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('shows a loading state while settings have not loaded yet', (tester) async {
    printTestDivider('SignInScreen shows a loading state while settings have not loaded yet');
    when(() => settingsCubit.state).thenReturn(SettingsInitial());
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => signInCubit.state).thenReturn(SignInInitial());
    when(() => customSmsCubit.state).thenReturn(CustomSmsSendPhoneOtpInitial());

    await tester.pumpWidget(buildScreen());

    printTestLog(
      'AuthScreenHeader → expected: absent while loading, actual: ${find.text(LanguageLabelKeys.welcomeBack).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.welcomeBack), findsNothing);
  });

  group('once settings are loaded (email login only)', () {
    // `_initModeIfNeeded` defaults `_mode` to phone whenever phone login is
    // enabled at all (`_isPhoneLogin ? phone : email`), regardless of email
    // also being enabled — email-only settings keep the default mode (and
    // this suite's field-count assumptions) deterministic without wading
    // into the tab-switch logic, which isn't this screen test's focus.
    setUp(() {
      when(() => settingsCubit.state).thenReturn(
        SettingsLoaded(AppSettings(data: settingsData(phoneLogin: '0'))),
      );
      when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => signInCubit.state).thenReturn(SignInInitial());
      when(() => customSmsCubit.state).thenReturn(CustomSmsSendPhoneOtpInitial());
    });

    testWidgets('renders the welcome header and the email sign-in form by default', (
      tester,
    ) async {
      printTestDivider(
        'SignInScreen renders the welcome header and the email sign-in form by default',
      );
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      printTestLog(
        'header → expected: present, actual: ${find.text(LanguageLabelKeys.welcomeBack).evaluate().isNotEmpty}',
      );
      expect(find.text(LanguageLabelKeys.welcomeBack), findsOneWidget);
      printTestLog(
        'email field label → expected: present, actual: ${find.text('${LanguageLabelKeys.email} *', findRichText: true).evaluate().isNotEmpty}',
      );
      expect(find.text('${LanguageLabelKeys.email} *', findRichText: true), findsOneWidget);
    });

    testWidgets(
      'submitting valid email/password calls SignInCubit.loginWithEmailPassword',
      (tester) async {
        printTestDivider(
          'SignInScreen submitting valid email/password calls SignInCubit.loginWithEmailPassword',
        );
        when(
          () => signInCubit.loginWithEmailPassword(
            id: any(named: 'id'),
            password: any(named: 'password'),
            type: any(named: 'type'),
            languageId: any(named: 'languageId'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildScreen());
        await tester.pump();

        await tester.enterText(
          find.byType(TextFormField).first,
          'jordan@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'Passw0rd!');
        await tester.tap(find.text(LanguageLabelKeys.signIn, findRichText: true));
        await tester.pump();

        final captured =
            verify(
                  () => signInCubit.loginWithEmailPassword(
                    id: captureAny(named: 'id'),
                    password: captureAny(named: 'password'),
                    type: captureAny(named: 'type'),
                    languageId: any(named: 'languageId'),
                  ),
                ).captured;
        printTestLog('id → expected: "jordan@example.com", actual: "${captured[0]}"');
        expect(captured[0], 'jordan@example.com');
        printTestLog('password → expected: "Passw0rd!", actual: "${captured[1]}"');
        expect(captured[1], 'Passw0rd!');
        printTestLog('type → expected: "${AuthType.email.name}", actual: "${captured[2]}"');
        expect(captured[2], AuthType.email.name);
      },
    );

    testWidgets('a SignInError state shows the message in a snackbar', (tester) async {
      printTestDivider('SignInScreen a SignInError state shows the message in a snackbar');
      whenListen<SignInState>(
        signInCubit,
        Stream.fromIterable([SignInError('Invalid credentials')]),
        initialState: SignInInitial(),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();

      printTestLog(
        'snackbar message → expected: present, actual: ${find.text('Invalid credentials').evaluate().isNotEmpty}',
      );
      expect(find.text('Invalid credentials'), findsOneWidget);
    });
  });
}
