import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/auth/screens/forgot_password_screen.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  // The sheet is private and only reachable through showForgotPasswordSheet,
  // so each test opens it from a host button the same way the login form does.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showForgotPasswordSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Bounded pumps rather than pumpAndSettle: the sheet body uses
    // SlideAnimationList (600ms staggered entrance) on top of the modal
    // route's own transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('opens with an email field and a submit button', (tester) async {
    printTestDivider('opens with an email field and a submit button');
    await openSheet(tester);

    printTestLog('AppTextField → expected: 1, actual: ${find.byType(AppTextField).evaluate().length}');
    expect(find.byType(AppTextField), findsOneWidget);
    printTestLog('AppButton    → expected: 1, actual: ${find.byType(AppButton).evaluate().length}');
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('submitting an empty email shows the required-email error', (
    tester,
  ) async {
    printTestDivider('submitting an empty email shows the required-email error');
    await openSheet(tester);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    // Translations aren't loaded in tests, so LocalizationService falls back
    // to the raw key — the key is what renders as the error text.
    printTestLog('error text → expected: "${LanguageLabelKeys.emailRequired}" visible');
    expect(find.text(LanguageLabelKeys.emailRequired), findsOneWidget);
  });

  testWidgets('submitting a malformed email shows the invalid-email error', (
    tester,
  ) async {
    printTestDivider('submitting a malformed email shows the invalid-email error');
    await openSheet(tester);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    printTestLog('error text → expected: "${LanguageLabelKeys.enterValidEmail}" visible');
    expect(find.text(LanguageLabelKeys.enterValidEmail), findsOneWidget);
  });
}
