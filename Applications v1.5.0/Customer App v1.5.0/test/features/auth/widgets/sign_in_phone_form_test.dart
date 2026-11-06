import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/auth/widgets/sign_in_phone_form.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  final country = CountriesData(id: 1, name: 'US', dialCode: '+1', minMobileLength: 10);

  testWidgets('hides the password field and forgot-password link when phone-password is disabled', (
    tester,
  ) async {
    printTestDivider(
      'SignInPhoneForm hides the password field when phone-password is disabled',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        SignInPhoneForm(
          phoneController: TextEditingController(),
          passwordController: TextEditingController(),
          isPhonePasswordEnabled: false,
          selectedCountry: country,
          onPhoneChanged: (_, _) {},
          onCountryChanged: (_) {},
          onForgotPassword: () {},
        ),
      ),
    );

    printTestLog(
      'Password label → expected: absent, actual: ${find.text('${LanguageLabelKeys.password} *', findRichText: true).evaluate().isEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.password} *', findRichText: true), findsNothing);
    printTestLog(
      'Forgot password link → expected: absent, actual: ${find.text(LanguageLabelKeys.forgotPassword, findRichText: true).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.forgotPassword, findRichText: true), findsNothing);
  });

  testWidgets('shows the password field and forgot-password link when phone-password is enabled', (
    tester,
  ) async {
    printTestDivider(
      'SignInPhoneForm shows the password field when phone-password is enabled',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        SignInPhoneForm(
          phoneController: TextEditingController(),
          passwordController: TextEditingController(),
          isPhonePasswordEnabled: true,
          selectedCountry: country,
          onPhoneChanged: (_, _) {},
          onCountryChanged: (_) {},
          onForgotPassword: () {},
        ),
      ),
    );

    printTestLog(
      'Password label → expected: present, actual: ${find.text('${LanguageLabelKeys.password} *', findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.password} *', findRichText: true), findsOneWidget);
  });

  testWidgets('surfaces a phone error message when phoneError is set', (tester) async {
    printTestDivider('SignInPhoneForm surfaces a phone error message when phoneError is set');
    await tester.pumpWidget(
      pumpTestWidget(
        SignInPhoneForm(
          phoneController: TextEditingController(),
          passwordController: TextEditingController(),
          isPhonePasswordEnabled: false,
          phoneError: 'Please enter a phone number',
          selectedCountry: country,
          onPhoneChanged: (_, _) {},
          onCountryChanged: (_) {},
          onForgotPassword: () {},
        ),
      ),
    );

    printTestLog(
      'error text → expected: present, actual: ${find.text('Please enter a phone number', findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text('Please enter a phone number', findRichText: true), findsOneWidget);
  });
}
