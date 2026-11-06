import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/widgets/auth_resend_section.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('shows a countdown (not the resend link) while the timer is running', (
    tester,
  ) async {
    printTestDivider(
      'AuthResendSection shows a countdown (not the resend link) while the timer is running',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        AuthResendSection(
          resendTimer: const Duration(seconds: 30),
          onResend: () {},
        ),
      ),
    );

    printTestLog(
      'resendOtp link → expected: absent, actual: ${find.text(LanguageLabelKeys.resendOtp).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.resendOtp), findsNothing);
    printTestLog(
      'countdown text → expected: present, actual: ${find.textContaining('30s').evaluate().isNotEmpty}',
    );
    expect(find.textContaining('30s'), findsOneWidget);
  });

  testWidgets('shows the tappable resend link once the timer hits zero', (tester) async {
    printTestDivider(
      'AuthResendSection shows the tappable resend link once the timer hits zero',
    );
    var tapped = false;

    await tester.pumpWidget(
      pumpTestWidget(
        AuthResendSection(
          resendTimer: Duration.zero,
          onResend: () => tapped = true,
        ),
      ),
    );

    printTestLog(
      'resendOtp link → expected: present, actual: ${find.text(LanguageLabelKeys.resendOtp).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.resendOtp), findsOneWidget);

    await tester.tap(find.text(LanguageLabelKeys.resendOtp));
    await tester.pump();

    printTestLog('onResend called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });
}
