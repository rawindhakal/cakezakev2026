import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/widgets/auth_terms_bar.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the terms/privacy links inline with the agreement copy', (
    tester,
  ) async {
    printTestDivider(
      'AuthTermsBar renders the terms/privacy links inline with the agreement copy',
    );
    await tester.pumpWidget(pumpTestWidget(const AuthTermsBar()));

    // The bar is one Text.rich span with the two links embedded as
    // WidgetSpans (each its own AppText/Text widget, not part of the outer
    // span's plain text) — find each link by its own text directly.
    printTestLog(
      'terms link → expected: present, actual: ${find.text(LanguageLabelKeys.termsAndConditions).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.termsAndConditions), findsOneWidget);
    printTestLog(
      'privacy link → expected: present, actual: ${find.text(LanguageLabelKeys.privacyPolicy).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.privacyPolicy), findsOneWidget);
  });
}
