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
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/screens/sign_up_screen.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// `SignUpScreen` reads `SettingsCubit` via `BlocBuilder`, `SignUpCubit`/
/// `CustomSmsSendPhoneOtpCubit` via `BlocListener`+`BlocBuilder`, and
/// `CountriesCubit` via `context.read` + a `BlocListener` for prefilling the
/// default country — all four must be provided, same cluster
/// `sign_in_screen_test.dart` already had to wire up.
///
/// `SignUpForm`'s phone field is validated as *required* regardless of
/// `mode` (`validator: ... required: !_isSocial`, and email mode isn't
/// social) — every successful-submit case here must fill in a phone number
/// even in email mode, or `_formKey.currentState!.validate()` silently
/// blocks `_onSignUp` before any cubit method is called.
void main() {
  late MockSettingsCubit settingsCubit;
  late MockSignUpCubit signUpCubit;
  late MockCustomSmsSendPhoneOtpCubit customSmsCubit;
  late MockCountriesCubit countriesCubit;

  AppSettingsData settingsData({
    String firebaseAuthentication = '0',
    String customSmsGatewayOtpBased = '0',
    String phoneAuthPassword = '0',
  }) => AppSettingsData(
    emailLogin: '1',
    phoneLogin: '1',
    googleLogin: '0',
    appleLogin: '0',
    firebaseAuthentication: firebaseAuthentication,
    customSmsGatewayOtpBased: customSmsGatewayOtpBased,
    phoneAuthPassword: phoneAuthPassword,
  );

  Widget buildScreen({
    AuthType mode = AuthType.email,
    bool otpVerified = false,
  }) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<SignUpCubit>.value(value: signUpCubit),
          BlocProvider<CustomSmsSendPhoneOtpCubit>.value(value: customSmsCubit),
          BlocProvider<CountriesCubit>.value(value: countriesCubit),
        ],
        child: SignUpScreen(mode: mode, otpVerified: otpVerified),
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
    signUpCubit = MockSignUpCubit();
    customSmsCubit = MockCustomSmsSendPhoneOtpCubit();
    countriesCubit = MockCountriesCubit();

    when(() => countriesCubit.state).thenReturn(CountriesInitial());
    when(() => countriesCubit.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => signUpCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => customSmsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => customSmsCubit.state)
        .thenReturn(CustomSmsSendPhoneOtpInitial());
  });

  testWidgets(
    'renders the sign-up form and Create Account CTA for email mode',
    (tester) async {
      printTestDivider(
        'SignUpScreen renders the sign-up form and Create Account CTA for email mode',
      );
      when(() => settingsCubit.state).thenReturn(SettingsLoaded(AppSettings(data: settingsData())));
      when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => signUpCubit.state).thenReturn(SignUpInitial());

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      printTestLog(
        'name field label → expected: present, actual: ${find.text('${LanguageLabelKeys.fullName} *', findRichText: true).evaluate().isNotEmpty}',
      );
      expect(find.text('${LanguageLabelKeys.fullName} *', findRichText: true), findsOneWidget);
      printTestLog(
        'email field label → expected: present, actual: ${find.text('${LanguageLabelKeys.email} *', findRichText: true).evaluate().isNotEmpty}',
      );
      expect(find.text('${LanguageLabelKeys.email} *', findRichText: true), findsOneWidget);
      printTestLog(
        'password field label → expected: present (email mode shows password), actual: ${find.text(LanguageLabelKeys.password, findRichText: true).evaluate().isNotEmpty}',
      );
      expect(find.text(LanguageLabelKeys.password, findRichText: true), findsOneWidget);
      printTestLog(
        'CTA label → expected: "${LanguageLabelKeys.createAccount}", actual present: ${find.text(LanguageLabelKeys.createAccount, findRichText: true).evaluate().isNotEmpty}',
      );
      expect(find.text(LanguageLabelKeys.createAccount, findRichText: true), findsWidgets);
    },
  );

  testWidgets(
    'phone mode with firebase OTP shows a Send OTP CTA that captures the phone number',
    (tester) async {
      printTestDivider(
        'SignUpScreen phone mode with firebase OTP shows a Send OTP CTA that captures the phone number',
      );
      when(() => settingsCubit.state).thenReturn(
        SettingsLoaded(AppSettings(data: settingsData(firebaseAuthentication: '1'))),
      );
      when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => signUpCubit.state).thenReturn(SignUpInitial());
      when(
        () => signUpCubit.sendPhoneOtpForSignUp(
          phoneNumber: any(named: 'phoneNumber'),
          countryCode: any(named: 'countryCode'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(mode: AuthType.phone));
      await tester.pump();

      printTestLog(
        'CTA label → expected: "${LanguageLabelKeys.sendOtp}", actual present: ${find.text(LanguageLabelKeys.sendOtp, findRichText: true).evaluate().isNotEmpty}',
      );
      expect(find.text(LanguageLabelKeys.sendOtp, findRichText: true), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Jordan Lee');
      await tester.enterText(find.byType(TextFormField).at(2), '9998887776');
      await tester.tap(find.text(LanguageLabelKeys.sendOtp, findRichText: true));
      await tester.pump();

      final captured = verify(
        () => signUpCubit.sendPhoneOtpForSignUp(
          phoneNumber: captureAny(named: 'phoneNumber'),
          countryCode: any(named: 'countryCode'),
        ),
      ).captured;
      printTestLog('phoneNumber → expected: "9998887776", actual: "${captured[0]}"');
      expect(captured[0], '9998887776');
    },
  );

  testWidgets('a SignUpError state shows the message in a snackbar', (tester) async {
    printTestDivider('SignUpScreen a SignUpError state shows the message in a snackbar');
    when(() => settingsCubit.state).thenReturn(SettingsLoaded(AppSettings(data: settingsData())));
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    whenListen<SignUpState>(
      signUpCubit,
      Stream.fromIterable([SignUpError('Email already registered')]),
      initialState: SignUpInitial(),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pump();

    printTestLog(
      'snackbar message → expected: present, actual: ${find.text('Email already registered').evaluate().isNotEmpty}',
    );
    expect(find.text('Email already registered'), findsOneWidget);
  });

  testWidgets(
    'submitting valid email/password (with a phone number, still required) calls SignUpCubit.signUpWithEmail',
    (tester) async {
      printTestDivider(
        'SignUpScreen submitting valid email/password calls SignUpCubit.signUpWithEmail',
      );
      when(() => settingsCubit.state).thenReturn(SettingsLoaded(AppSettings(data: settingsData())));
      when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => signUpCubit.state).thenReturn(SignUpInitial());
      when(
        () => signUpCubit.signUpWithEmail(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          mobile: any(named: 'mobile'),
          countryCode: any(named: 'countryCode'),
          countryId: any(named: 'countryId'),
          friendsCode: any(named: 'friendsCode'),
          languageId: any(named: 'languageId'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Jordan Lee');
      await tester.enterText(find.byType(TextFormField).at(1), 'jordan@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), '9998887776');
      await tester.enterText(find.byType(TextFormField).at(4), 'Passw0rd!');
      await tester.enterText(find.byType(TextFormField).at(5), 'Passw0rd!');
      await tester.tap(find.text(LanguageLabelKeys.createAccount, findRichText: true).last);
      await tester.pump();

      final captured = verify(
        () => signUpCubit.signUpWithEmail(
          name: captureAny(named: 'name'),
          email: captureAny(named: 'email'),
          password: captureAny(named: 'password'),
          mobile: any(named: 'mobile'),
          countryCode: any(named: 'countryCode'),
          countryId: any(named: 'countryId'),
          friendsCode: any(named: 'friendsCode'),
          languageId: any(named: 'languageId'),
        ),
      ).captured;
      printTestLog('name → expected: "Jordan Lee", actual: "${captured[0]}"');
      expect(captured[0], 'Jordan Lee');
      printTestLog('email → expected: "jordan@example.com", actual: "${captured[1]}"');
      expect(captured[1], 'jordan@example.com');
      printTestLog('password → expected: "Passw0rd!", actual: "${captured[2]}"');
      expect(captured[2], 'Passw0rd!');
    },
  );
}
