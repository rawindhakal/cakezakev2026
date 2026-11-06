import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/features/auth/widgets/login_form.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockSignInCubit signInCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late TextEditingController emailController;
  late TextEditingController passwordController;

  setUp(() {
    signInCubit = MockSignInCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    whenListen(
      signInCubit,
      const Stream<SignInState>.empty(),
      initialState: const SignInInitial(),
    );
  });

  tearDown(() {
    emailController.dispose();
    passwordController.dispose();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  // Providers sit above MaterialApp so the forgot-password sheet — a sibling
  // route on the same Navigator — can still read them.
  Widget buildSubject({VoidCallback? onLogin}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SignInCubit>.value(value: signInCubit),
        BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
      ],
      child: pumpTestWidget(
        Form(
          child: LoginForm(
            emailController: emailController,
            passwordController: passwordController,
            onLogin: onLogin ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders email and password fields plus the login button', (
    tester,
  ) async {
    printTestDivider('renders email and password fields plus the login button');
    await tester.pumpWidget(buildSubject());

    final fieldCount = find.byType(AppTextField).evaluate().length;
    printTestLog('AppTextField count → expected: 2, actual: $fieldCount');
    expect(find.byType(AppTextField), findsNWidgets(2));
    printTestLog('AppButton → expected: 1, actual: ${find.byType(AppButton).evaluate().length}');
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('tapping the login button invokes the onLogin callback', (
    tester,
  ) async {
    printTestDivider('tapping the login button invokes the onLogin callback');
    var tapped = false;
    await tester.pumpWidget(buildSubject(onLogin: () => tapped = true));

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    printTestLog('onLogin called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });

  testWidgets('email validator rejects an empty value', (tester) async {
    printTestDivider('email validator rejects an empty value');
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SignInCubit>.value(value: signInCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(
          Form(
            key: formKey,
            child: LoginForm(
              emailController: emailController,
              passwordController: passwordController,
              onLogin: () {},
            ),
          ),
        ),
      ),
    );

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('form.validate() → expected: false, actual: $isValid');
    expect(isValid, isFalse);
    // Translations aren't loaded in tests, so LocalizationService falls back
    // to the raw key — the key is what renders as the error text.
    printTestLog('error text → expected: "${LanguageLabelKeys.emailRequired}" visible');
    expect(find.text(LanguageLabelKeys.emailRequired), findsOneWidget);
  });

  testWidgets('email validator rejects a malformed address', (tester) async {
    printTestDivider('email validator rejects a malformed address');
    final formKey = GlobalKey<FormState>();
    emailController.text = 'not-an-email';
    passwordController.text = 'pass123';

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SignInCubit>.value(value: signInCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(
          Form(
            key: formKey,
            child: LoginForm(
              emailController: emailController,
              passwordController: passwordController,
              onLogin: () {},
            ),
          ),
        ),
      ),
    );

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('form.validate() → expected: false, actual: $isValid');
    expect(isValid, isFalse);
    printTestLog('error text → expected: "${LanguageLabelKeys.enterValidEmail}" visible');
    expect(find.text(LanguageLabelKeys.enterValidEmail), findsOneWidget);
  });

  testWidgets('form validates when email and password are both filled', (
    tester,
  ) async {
    printTestDivider('form validates when email and password are both filled');
    final formKey = GlobalKey<FormState>();
    emailController.text = 'a@a.com';
    passwordController.text = 'pass123';

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SignInCubit>.value(value: signInCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(
          Form(
            key: formKey,
            child: LoginForm(
              emailController: emailController,
              passwordController: passwordController,
              onLogin: () {},
            ),
          ),
        ),
      ),
    );

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('form.validate() → expected: true, actual: $isValid');
    expect(isValid, isTrue);
  });

  testWidgets('shows the button spinner while SignInCubit is loading', (
    tester,
  ) async {
    printTestDivider('shows the button spinner while SignInCubit is loading');
    whenListen(
      signInCubit,
      Stream<SignInState>.fromIterable([const SignInLoading()]),
      initialState: const SignInInitial(),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final button = tester.widget<AppButton>(find.byType(AppButton));
    printTestLog('AppButton.isLoading → expected: true, actual: ${button.isLoading}');
    expect(button.isLoading, isTrue);
  });

  testWidgets('password field starts obscured and toggles on suffix tap', (
    tester,
  ) async {
    printTestDivider('password field starts obscured and toggles on suffix tap');
    await tester.pumpWidget(buildSubject());

    AppTextField passwordField() =>
        tester.widget<AppTextField>(find.byType(AppTextField).at(1));

    printTestLog('obscureText initially → expected: true, actual: ${passwordField().obscureText}');
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    printTestLog('obscureText after tap → expected: false, actual: ${passwordField().obscureText}');
    expect(passwordField().obscureText, isFalse);
  });
}
