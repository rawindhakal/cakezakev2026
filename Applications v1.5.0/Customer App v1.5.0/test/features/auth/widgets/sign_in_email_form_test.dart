import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/widgets/sign_in_email_form.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the email and password fields plus a forgot-password link', (
    tester,
  ) async {
    printTestDivider(
      'SignInEmailForm renders the email and password fields plus a forgot-password link',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        SignInEmailForm(
          emailController: TextEditingController(),
          passwordController: TextEditingController(),
          onForgotPassword: () {},
        ),
      ),
    );

    printTestLog(
      'Email label → expected: present, actual: ${find.text('${LanguageLabelKeys.email} *', findRichText: true).evaluate().isNotEmpty}',
    );
    // Both fields are `isRequired: true`, so `AppText` renders them as a
    // standalone RichText with a trailing " *" (not a plain Text) — match
    // the full rendered string, not just the translation key.
    expect(find.text('${LanguageLabelKeys.email} *', findRichText: true), findsOneWidget);
    printTestLog(
      'Password label → expected: present, actual: ${find.text('${LanguageLabelKeys.password} *', findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.password} *', findRichText: true), findsOneWidget);
    printTestLog(
      'Forgot password link → expected: present, actual: ${find.text(LanguageLabelKeys.forgotPassword, findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.forgotPassword, findRichText: true), findsOneWidget);
  });

  testWidgets('tapping the forgot-password link calls onForgotPassword', (tester) async {
    printTestDivider(
      'SignInEmailForm tapping the forgot-password link calls onForgotPassword',
    );
    var tapped = false;

    await tester.pumpWidget(
      pumpTestWidget(
        SignInEmailForm(
          emailController: TextEditingController(),
          passwordController: TextEditingController(),
          onForgotPassword: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text(LanguageLabelKeys.forgotPassword, findRichText: true));
    await tester.pump();

    printTestLog('onForgotPassword called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });
}
