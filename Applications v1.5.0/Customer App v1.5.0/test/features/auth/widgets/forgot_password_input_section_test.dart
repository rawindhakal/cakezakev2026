import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/auth/widgets/forgot_password_input_section.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  final country = CountriesData(id: 1, name: 'US', dialCode: '+1', minMobileLength: 10);

  testWidgets('renders the email field (not the phone field) when isPhone is false', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordInputSection renders the email field when isPhone is false',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        ForgotPasswordInputSection(
          isPhone: false,
          emailController: TextEditingController(),
          phoneController: TextEditingController(),
          isLoading: false,
          selectedCountry: country,
          onCountryCodeChanged: (_) {},
          onCountryChanged: (_) {},
          onSendOtp: () {},
        ),
      ),
    );

    printTestLog(
      'Email label → expected: present, actual: ${find.text(LanguageLabelKeys.email).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.email), findsOneWidget);
    printTestLog(
      'Phone label → expected: absent, actual: ${find.text(LanguageLabelKeys.phoneNumber).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.phoneNumber), findsNothing);
  });

  testWidgets('renders the phone field (not the email field) when isPhone is true', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordInputSection renders the phone field when isPhone is true',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        ForgotPasswordInputSection(
          isPhone: true,
          emailController: TextEditingController(),
          phoneController: TextEditingController(),
          isLoading: false,
          selectedCountry: country,
          onCountryCodeChanged: (_) {},
          onCountryChanged: (_) {},
          onSendOtp: () {},
        ),
      ),
    );

    printTestLog(
      'Phone label → expected: present, actual: ${find.text(LanguageLabelKeys.phoneNumber).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.phoneNumber), findsOneWidget);
    printTestLog(
      'Email label → expected: absent, actual: ${find.text(LanguageLabelKeys.email).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.email), findsNothing);
  });

  testWidgets('the Send OTP button is disabled (onPressed null) while isLoading is true', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordInputSection the Send OTP button is disabled while isLoading is true',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        ForgotPasswordInputSection(
          isPhone: false,
          emailController: TextEditingController(),
          phoneController: TextEditingController(),
          isLoading: true,
          selectedCountry: country,
          onCountryCodeChanged: (_) {},
          onCountryChanged: (_) {},
          onSendOtp: () {},
        ),
      ),
    );

    // AppButton swaps its label for a spinner while isLoading, so the
    // "send_otp" text isn't even in the tree — assert on onPressed instead.
    final button = tester.widget<AppButton>(find.byType(AppButton));
    printTestLog('onPressed → expected: null, actual: ${button.onPressed}');
    expect(button.onPressed, isNull);
  });
}
