import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/widgets/delivery_otp_bottom_sheet.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  /// Opens the sheet through its real entry point from a host screen, so the
  /// Navigator has a route to return to when the sheet pops.
  Future<String?> openSheet(
    WidgetTester tester, {
    required int? expectedOtp,
  }) async {
    String? result;
    var popped = false;

    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDeliveryOtpBottomSheet(
                context: context,
                expectedOtp: expectedOtp,
              );
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // The sheet's SlideAnimationList staggers its children in; a child that is
    // still animating is not hit-testable, so a tap on it silently misses.
    // Pump well past the entrance before interacting.
    await tester.pump(const Duration(seconds: 1));

    // `popped` is only read to keep the closure's result assignment alive for
    // the analyzer; the value itself is asserted through `result`.
    expect(popped, isFalse);
    return result;
  }

  /// Enters [otp] into the sheet's single text field.
  Future<void> enterOtp(WidgetTester tester, String otp) async {
    await tester.enterText(find.byType(AppTextField), otp);
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(find.text(LanguageLabelKeys.submit));
    await tester.pump();
    // Long enough for the pop transition plus the awaiting caller's
    // continuation to run.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the prompt, a field and two actions', (tester) async {
    printTestDivider('shows the prompt, a field and two actions');
    await openSheet(tester, expectedOtp: 576400);

    // Translations aren't loaded in tests, so copy falls back to raw keys.
    printTestLog('title → expected: "${LanguageLabelKeys.enterDeliveryOtp}" visible');
    expect(find.text(LanguageLabelKeys.enterDeliveryOtp), findsOneWidget);
    printTestLog('field → expected: 1, actual: ${find.byType(AppTextField).evaluate().length}');
    expect(find.byType(AppTextField), findsOneWidget);
    printTestLog('buttons → expected: 2, actual: ${find.byType(AppButton).evaluate().length}');
    expect(find.byType(AppButton), findsNWidgets(2));
  });

  testWidgets('stays quiet while fewer digits than expected are typed', (
    tester,
  ) async {
    printTestDivider('stays quiet while fewer digits than expected are typed');
    await openSheet(tester, expectedOtp: 576400);

    // No "invalid" nagging until the rider has typed a full-length code.
    await enterOtp(tester, '5764');

    printTestLog('error → expected: absent, actual: ${find.text(LanguageLabelKeys.invalidOtp).evaluate().length}');
    expect(find.text(LanguageLabelKeys.invalidOtp), findsNothing);
  });

  testWidgets('flags a wrong code once it reaches full length', (tester) async {
    printTestDivider('flags a wrong code once it reaches full length');
    await openSheet(tester, expectedOtp: 576400);

    await enterOtp(tester, '000000');

    printTestLog('error → expected: "${LanguageLabelKeys.invalidOtp}" visible');
    expect(find.text(LanguageLabelKeys.invalidOtp), findsOneWidget);
  });

  testWidgets('clears the error when the rider edits the code back down', (
    tester,
  ) async {
    printTestDivider('clears the error when the rider edits the code back down');
    await openSheet(tester, expectedOtp: 576400);

    await enterOtp(tester, '000000');
    expect(find.text(LanguageLabelKeys.invalidOtp), findsOneWidget);

    await enterOtp(tester, '00000');

    printTestLog('error → expected: cleared, actual: ${find.text(LanguageLabelKeys.invalidOtp).evaluate().length}');
    expect(find.text(LanguageLabelKeys.invalidOtp), findsNothing);
  });

  testWidgets('accepts a matching code and returns it to the caller', (
    tester,
  ) async {
    printTestDivider('accepts a matching code and returns it to the caller');
    String? returned;
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              returned = await showDeliveryOtpBottomSheet(
                context: context,
                expectedOtp: 576400,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await enterOtp(tester, '576400');
    await tapSubmit(tester);

    printTestLog('returned OTP → expected: "576400", actual: "$returned"');
    expect(returned, '576400');
    printTestLog('sheet → expected: closed, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}');
    expect(find.byType(DeliveryOtpBottomSheet), findsNothing);
  });

  testWidgets('refuses to submit a wrong code and keeps the sheet open', (
    tester,
  ) async {
    printTestDivider('refuses to submit a wrong code and keeps the sheet open');
    await openSheet(tester, expectedOtp: 576400);

    await enterOtp(tester, '111111');
    await tapSubmit(tester);

    printTestLog('sheet → expected: still open, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}');
    expect(find.byType(DeliveryOtpBottomSheet), findsOneWidget);
    printTestLog('error → expected: "${LanguageLabelKeys.invalidOtp}" visible');
    expect(find.text(LanguageLabelKeys.invalidOtp), findsOneWidget);
  });

  testWidgets('refuses an empty submission', (tester) async {
    printTestDivider('refuses an empty submission');
    await openSheet(tester, expectedOtp: 576400);

    await tapSubmit(tester);

    printTestLog('sheet → expected: still open, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}');
    expect(find.byType(DeliveryOtpBottomSheet), findsOneWidget);
    printTestLog('error → expected: "${LanguageLabelKeys.invalidOtp}" visible');
    expect(find.text(LanguageLabelKeys.invalidOtp), findsOneWidget);
  });

  testWidgets('never accepts anything when the order carries no OTP', (
    tester,
  ) async {
    printTestDivider('never accepts anything when the order carries no OTP');
    // With no expected code there is nothing to match, so submitting must not
    // hand back a value that would then be sent to the server.
    await openSheet(tester, expectedOtp: null);

    await enterOtp(tester, '000000');
    await tapSubmit(tester);

    printTestLog('sheet → expected: still open, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}');
    expect(find.byType(DeliveryOtpBottomSheet), findsOneWidget);
  });

  testWidgets('cancel closes the sheet without returning a code', (tester) async {
    printTestDivider('cancel closes the sheet without returning a code');
    String? returned = 'untouched';
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              returned = await showDeliveryOtpBottomSheet(
                context: context,
                expectedOtp: 576400,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text(LanguageLabelKeys.cancel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog('returned → expected: null, actual: $returned');
    expect(returned, isNull);
    printTestLog('sheet → expected: closed, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}');
    expect(find.byType(DeliveryOtpBottomSheet), findsNothing);
  });
}
