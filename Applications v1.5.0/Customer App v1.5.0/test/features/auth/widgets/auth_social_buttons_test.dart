import 'package:flutter_test/flutter_test.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/widgets/auth_social_buttons.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders only the Google button when only Google is enabled', (tester) async {
    printTestDivider(
      'AuthSocialButtons renders only the Google button when only Google is enabled',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        AuthSocialButtons(
          isGoogleEnabled: true,
          isAppleEnabled: false,
          onGoogleSignIn: () {},
          onAppleSignIn: () {},
        ),
      ),
    );

    printTestLog(
      'Google button → expected: present, actual: ${find.text(LanguageLabelKeys.continueWithGoogle).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.continueWithGoogle), findsOneWidget);
    printTestLog(
      'Apple button → expected: absent, actual: ${find.text(LanguageLabelKeys.continueWithApple).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.continueWithApple), findsNothing);
  });

  testWidgets(
    'the Apple button never renders under `flutter test` even when enabled — `Platform.isIOS` is false on the host test VM, not just non-iOS devices',
    (tester) async {
      printTestDivider(
        'AuthSocialButtons the Apple button never renders under flutter test even when enabled',
      );
      await tester.pumpWidget(
        pumpTestWidget(
          AuthSocialButtons(
            isGoogleEnabled: false,
            isAppleEnabled: true,
            onGoogleSignIn: () {},
            onAppleSignIn: () {},
          ),
        ),
      );

      printTestLog(
        'Apple button on host test VM → expected: absent, actual: ${find.text(LanguageLabelKeys.continueWithApple).evaluate().isEmpty}',
      );
      expect(find.text(LanguageLabelKeys.continueWithApple), findsNothing);
    },
  );

  testWidgets('tapping the Google button calls onGoogleSignIn when not loading', (
    tester,
  ) async {
    printTestDivider(
      'AuthSocialButtons tapping the Google button calls onGoogleSignIn when not loading',
    );
    var tapped = false;

    await tester.pumpWidget(
      pumpTestWidget(
        AuthSocialButtons(
          isGoogleEnabled: true,
          isAppleEnabled: false,
          onGoogleSignIn: () => tapped = true,
          onAppleSignIn: () {},
        ),
      ),
    );

    await tester.tap(find.text(LanguageLabelKeys.continueWithGoogle));
    await tester.pump();

    printTestLog('onGoogleSignIn called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });

  testWidgets('the Google button is disabled (onPressed null) while isLoading is true', (
    tester,
  ) async {
    printTestDivider(
      'AuthSocialButtons the Google button is disabled while isLoading is true',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        AuthSocialButtons(
          isGoogleEnabled: true,
          isAppleEnabled: false,
          isLoading: true,
          onGoogleSignIn: () {},
          onAppleSignIn: () {},
        ),
      ),
    );

    final button = tester.widget<AppButton>(find.byType(AppButton));
    printTestLog('onPressed → expected: null, actual: ${button.onPressed}');
    expect(button.onPressed, isNull);
  });
}
