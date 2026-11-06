import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';
import 'package:customer/features/auth/screens/otp_verification_screen.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// `OtpVerificationScreen` reads `SettingsCubit` directly via `context.read`
/// (not `BlocBuilder`) inside `_isFirebaseOtp`, plus `SignInCubit`/
/// `CustomSmsSendPhoneOtpCubit`/`CustomSmsVerifyPhoneOtpCubit` via
/// `BlocListener`/`BlocBuilder` — all four must be provided. `_onVerify`
/// branches purely on `widget.authType == OtpAuthType.custom.name`: firebase
/// (the default) drives `SignInCubit.verifyPhoneOtp`, custom drives
/// `CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp` — covering both
/// branches here since it's the screen's one real fork.
void main() {
  late MockSettingsCubit settingsCubit;
  late MockSignInCubit signInCubit;
  late MockCustomSmsSendPhoneOtpCubit customSmsSendCubit;
  late MockCustomSmsVerifyPhoneOtpCubit customSmsVerifyCubit;

  Widget buildScreen({String authType = 'firebase'}) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<SignInCubit>.value(value: signInCubit),
          BlocProvider<CustomSmsSendPhoneOtpCubit>.value(value: customSmsSendCubit),
          BlocProvider<CustomSmsVerifyPhoneOtpCubit>.value(value: customSmsVerifyCubit),
        ],
        child: OtpVerificationScreen(
          phoneNumber: '9998887776',
          authType: authType,
          countryCode: '+1',
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
    signInCubit = MockSignInCubit();
    customSmsSendCubit = MockCustomSmsSendPhoneOtpCubit();
    customSmsVerifyCubit = MockCustomSmsVerifyPhoneOtpCubit();

    when(() => settingsCubit.state).thenReturn(
      SettingsLoaded(AppSettings(data: AppSettingsData(firebaseAuthentication: '1'))),
    );
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => signInCubit.state).thenReturn(SignInInitial());
    when(() => signInCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => customSmsSendCubit.state)
        .thenReturn(CustomSmsSendPhoneOtpInitial());
    when(() => customSmsSendCubit.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => customSmsVerifyCubit.state)
        .thenReturn(CustomSmsVerifyPhoneOtpInitial());
    when(() => customSmsVerifyCubit.stream)
        .thenAnswer((_) => const Stream.empty());
  });

  testWidgets('renders the code-sent-to text and the OTP/resend widgets', (tester) async {
    printTestDivider('OtpVerificationScreen renders the code-sent-to text and the OTP/resend widgets');
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    printTestLog(
      'code sent text → expected: present, actual: ${find.textContaining('9998887776').evaluate().isNotEmpty}',
    );
    expect(find.textContaining('9998887776'), findsOneWidget);
    printTestLog(
      'Pinput → expected: present, actual: ${find.byType(Pinput).evaluate().isNotEmpty}',
    );
    expect(find.byType(Pinput), findsOneWidget);
  });

  testWidgets(
    'tapping verify with an incomplete OTP shows a validation snackbar without calling any cubit',
    (tester) async {
      printTestDivider(
        'OtpVerificationScreen tapping verify with an incomplete OTP shows a validation snackbar',
      );
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.enterText(find.byType(Pinput), '123');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      printTestLog(
        'validation snackbar → expected: present, actual: ${find.text(LanguageLabelKeys.enterOtp).evaluate().isNotEmpty}',
      );
      expect(find.text(LanguageLabelKeys.enterOtp), findsOneWidget);
      verifyNever(
        () => signInCubit.verifyPhoneOtp(
          phoneNumber: any(named: 'phoneNumber'),
          type: any(named: 'type'),
          phoneAuthType: any(named: 'phoneAuthType'),
          countryCode: any(named: 'countryCode'),
        ),
      );
    },
  );

  testWidgets(
    'firebase authType: a full OTP calls SignInCubit.verifyPhoneOtp with the right args',
    (tester) async {
      printTestDivider(
        'OtpVerificationScreen firebase authType calls SignInCubit.verifyPhoneOtp',
      );
      when(
        () => signInCubit.verifyPhoneOtp(
          phoneNumber: any(named: 'phoneNumber'),
          type: any(named: 'type'),
          phoneAuthType: any(named: 'phoneAuthType'),
          languageId: any(named: 'languageId'),
          countryCode: any(named: 'countryCode'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(authType: 'firebase'));
      await tester.pump();

      await tester.enterText(find.byType(Pinput), '123456');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      final captured = verify(
        () => signInCubit.verifyPhoneOtp(
          phoneNumber: captureAny(named: 'phoneNumber'),
          type: captureAny(named: 'type'),
          phoneAuthType: captureAny(named: 'phoneAuthType'),
          languageId: any(named: 'languageId'),
          countryCode: captureAny(named: 'countryCode'),
        ),
      ).captured;
      printTestLog('phoneNumber → expected: "9998887776", actual: "${captured[0]}"');
      expect(captured[0], '9998887776');
      printTestLog('type → expected: "${AuthType.phone.name}", actual: "${captured[1]}"');
      expect(captured[1], AuthType.phone.name);
      printTestLog('phoneAuthType → expected: "${ApiParameters.phoneAuthOtp}", actual: "${captured[2]}"');
      expect(captured[2], ApiParameters.phoneAuthOtp);
      printTestLog('countryCode → expected: "+1", actual: "${captured[3]}"');
      expect(captured[3], '+1');
    },
  );

  testWidgets(
    'custom authType: a full OTP calls CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp',
    (tester) async {
      printTestDivider(
        'OtpVerificationScreen custom authType calls CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp',
      );
      when(
        () => customSmsVerifyCubit.customSmsVerifyPhoneOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otp: any(named: 'otp'),
          countryCode: any(named: 'countryCode'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(authType: OtpAuthType.custom.name));
      await tester.pump();

      await tester.enterText(find.byType(Pinput), '654321');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      final captured = verify(
        () => customSmsVerifyCubit.customSmsVerifyPhoneOtp(
          phoneNumber: captureAny(named: 'phoneNumber'),
          otp: captureAny(named: 'otp'),
          countryCode: any(named: 'countryCode'),
        ),
      ).captured;
      printTestLog('phoneNumber → expected: "9998887776", actual: "${captured[0]}"');
      expect(captured[0], '9998887776');
      printTestLog('otp → expected: "654321", actual: "${captured[1]}"');
      expect(captured[1], '654321');
    },
  );

  testWidgets('a SignInError state shows the message in a snackbar', (tester) async {
    printTestDivider('OtpVerificationScreen a SignInError state shows the message in a snackbar');
    whenListen<SignInState>(
      signInCubit,
      Stream.fromIterable([SignInError('OTP verification failed')]),
      initialState: SignInInitial(),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pump();

    printTestLog(
      'snackbar message → expected: present, actual: ${find.text('OTP verification failed').evaluate().isNotEmpty}',
    );
    expect(find.text('OTP verification failed'), findsOneWidget);
  });
}
