import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/cubits/verify_otp_cubit.dart';
import 'package:customer/features/auth/screens/register_otp_screen.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// `RegisterOtpScreen` reads `VerifyOtpCubit`/`SignUpCubit`/
/// `CustomSmsSendPhoneOtpCubit`/`CustomSmsVerifyPhoneOtpCubit` — all four via
/// `MultiBlocListener`, three of them again via nested `BlocBuilder`s for the
/// verify button's loading state — so all four must be provided regardless
/// of `args.authType`. `_onVerify` branches on `args.authType` three ways
/// (email → `VerifyOtpCubit.verifyEmail`, firebase →
/// `VerifyOtpCubit.verifyPhoneOtpAndSignUp`, custom →
/// `CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp`) — covering all
/// three since this screen's whole reason to exist is that fork.
void main() {
  late MockVerifyOtpCubit verifyOtpCubit;
  late MockSignUpCubit signUpCubit;
  late MockCustomSmsSendPhoneOtpCubit customSmsSendCubit;
  late MockCustomSmsVerifyPhoneOtpCubit customSmsVerifyCubit;

  Widget buildScreen(RegisterOtpArgs args) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<VerifyOtpCubit>.value(value: verifyOtpCubit),
          BlocProvider<SignUpCubit>.value(value: signUpCubit),
          BlocProvider<CustomSmsSendPhoneOtpCubit>.value(value: customSmsSendCubit),
          BlocProvider<CustomSmsVerifyPhoneOtpCubit>.value(value: customSmsVerifyCubit),
        ],
        child: RegisterOtpScreen(args: args),
      ),
    );
  }

  setUpAll(() => HiveTestHelper.setUp(settingsBox));
  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  setUp(() {
    verifyOtpCubit = MockVerifyOtpCubit();
    signUpCubit = MockSignUpCubit();
    customSmsSendCubit = MockCustomSmsSendPhoneOtpCubit();
    customSmsVerifyCubit = MockCustomSmsVerifyPhoneOtpCubit();

    when(() => verifyOtpCubit.state).thenReturn(VerifyOtpInitial());
    when(() => verifyOtpCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => signUpCubit.state).thenReturn(SignUpInitial());
    when(() => signUpCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => customSmsSendCubit.state)
        .thenReturn(CustomSmsSendPhoneOtpInitial());
    when(() => customSmsSendCubit.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => customSmsVerifyCubit.state)
        .thenReturn(CustomSmsVerifyPhoneOtpInitial());
    when(() => customSmsVerifyCubit.stream)
        .thenAnswer((_) => const Stream.empty());
  });

  testWidgets('email authType renders the target email and the OTP field', (tester) async {
    printTestDivider('RegisterOtpScreen email authType renders the target email and the OTP field');
    await tester.pumpWidget(
      buildScreen(
        RegisterOtpArgs(
          name: 'Jordan Lee',
          email: 'jordan@example.com',
          phoneAuthType: PhoneAuthType.password.apiValue,
          authType: OtpAuthType.email.name,
        ),
      ),
    );
    await tester.pump();

    printTestLog(
      'target email → expected: present, actual: ${find.textContaining('jordan@example.com').evaluate().isNotEmpty}',
    );
    expect(find.textContaining('jordan@example.com'), findsOneWidget);
    printTestLog(
      'Pinput → expected: present, actual: ${find.byType(Pinput).evaluate().isNotEmpty}',
    );
    expect(find.byType(Pinput), findsOneWidget);
  });

  testWidgets('email authType: a full OTP calls VerifyOtpCubit.verifyEmail', (tester) async {
    printTestDivider('RegisterOtpScreen email authType calls VerifyOtpCubit.verifyEmail');
    when(
      () => verifyOtpCubit.verifyEmail(
        email: any(named: 'email'),
        otp: any(named: 'otp'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildScreen(
        RegisterOtpArgs(
          name: 'Jordan Lee',
          email: 'jordan@example.com',
          phoneAuthType: PhoneAuthType.password.apiValue,
          authType: OtpAuthType.email.name,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(Pinput), '123456');
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    final captured = verify(
      () => verifyOtpCubit.verifyEmail(
        email: captureAny(named: 'email'),
        otp: captureAny(named: 'otp'),
      ),
    ).captured;
    printTestLog('email → expected: "jordan@example.com", actual: "${captured[0]}"');
    expect(captured[0], 'jordan@example.com');
    printTestLog('otp → expected: "123456", actual: "${captured[1]}"');
    expect(captured[1], '123456');
  });

  testWidgets(
    'firebase authType: a full OTP calls VerifyOtpCubit.verifyPhoneOtpAndSignUp with the right args',
    (tester) async {
      printTestDivider(
        'RegisterOtpScreen firebase authType calls VerifyOtpCubit.verifyPhoneOtpAndSignUp',
      );
      when(
        () => verifyOtpCubit.verifyPhoneOtpAndSignUp(
          verificationId: any(named: 'verificationId'),
          smsCode: any(named: 'smsCode'),
          name: any(named: 'name'),
          mobile: any(named: 'mobile'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          phoneAuthType: any(named: 'phoneAuthType'),
          friendsCode: any(named: 'friendsCode'),
          languageId: any(named: 'languageId'),
          countryCode: any(named: 'countryCode'),
          countryId: any(named: 'countryId'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildScreen(
          RegisterOtpArgs(
            name: 'Jordan Lee',
            phone: '9998887776',
            countryCode: '+1',
            phoneAuthType: PhoneAuthType.otp.apiValue,
            authType: OtpAuthType.firebase.name,
            verificationId: 'vid-123',
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(Pinput), '654321');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      final captured = verify(
        () => verifyOtpCubit.verifyPhoneOtpAndSignUp(
          verificationId: captureAny(named: 'verificationId'),
          smsCode: captureAny(named: 'smsCode'),
          name: captureAny(named: 'name'),
          mobile: captureAny(named: 'mobile'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          phoneAuthType: any(named: 'phoneAuthType'),
          friendsCode: any(named: 'friendsCode'),
          languageId: any(named: 'languageId'),
          countryCode: any(named: 'countryCode'),
          countryId: any(named: 'countryId'),
        ),
      ).captured;
      printTestLog('verificationId → expected: "vid-123", actual: "${captured[0]}"');
      expect(captured[0], 'vid-123');
      printTestLog('smsCode → expected: "654321", actual: "${captured[1]}"');
      expect(captured[1], '654321');
      printTestLog('name → expected: "Jordan Lee", actual: "${captured[2]}"');
      expect(captured[2], 'Jordan Lee');
      printTestLog('mobile → expected: "9998887776", actual: "${captured[3]}"');
      expect(captured[3], '9998887776');
    },
  );

  testWidgets(
    'custom authType: a full OTP calls CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp',
    (tester) async {
      printTestDivider(
        'RegisterOtpScreen custom authType calls CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp',
      );
      when(
        () => customSmsVerifyCubit.customSmsVerifyPhoneOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otp: any(named: 'otp'),
          countryCode: any(named: 'countryCode'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildScreen(
          RegisterOtpArgs(
            name: 'Jordan Lee',
            phone: '9998887776',
            countryCode: '+1',
            phoneAuthType: PhoneAuthType.otp.apiValue,
            authType: OtpAuthType.custom.name,
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(Pinput), '111222');
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
      printTestLog('otp → expected: "111222", actual: "${captured[1]}"');
      expect(captured[1], '111222');
    },
  );

  testWidgets('a VerifyOtpError state shows the message in a snackbar', (tester) async {
    printTestDivider('RegisterOtpScreen a VerifyOtpError state shows the message in a snackbar');
    whenListen<VerifyOtpState>(
      verifyOtpCubit,
      Stream.fromIterable([VerifyOtpError('Invalid OTP')]),
      initialState: VerifyOtpInitial(),
    );

    await tester.pumpWidget(
      buildScreen(
        RegisterOtpArgs(
          name: 'Jordan Lee',
          email: 'jordan@example.com',
          phoneAuthType: PhoneAuthType.password.apiValue,
          authType: OtpAuthType.email.name,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    printTestLog(
      'snackbar message → expected: present, actual: ${find.text('Invalid OTP').evaluate().isNotEmpty}',
    );
    expect(find.text('Invalid OTP'), findsOneWidget);
  });
}
