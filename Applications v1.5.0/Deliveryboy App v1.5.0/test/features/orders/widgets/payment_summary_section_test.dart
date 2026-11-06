import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/features/orders/widgets/bill_row.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpSummary(WidgetTester tester, PaymentBreakdown breakdown) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(
          child: PaymentSummarySection(breakdown: breakdown, symbol: '₹'),
        ),
      ),
    );
    await tester.pump();
  }

  group('PaymentSummarySection', () {
    testWidgets('shows a single total row for a one-method order', (
      tester,
    ) async {
      printTestDivider('shows a single total row for a one-method order');
      await pumpSummary(
        tester,
        PaymentBreakdown.compute(remainingAmount: 246.3, paymentMethod: 'Razorpay'),
      );

      // Translations aren't loaded in tests, so labels fall back to raw keys.
      printTestLog('label → expected: "${LanguageLabelKeys.paidVia} Razorpay" visible');
      expect(
        find.text('${LanguageLabelKeys.paidVia} Razorpay'),
        findsOneWidget,
      );
      printTestLog('amount → expected: "₹246" visible');
      expect(find.text('₹246'), findsOneWidget);
      printTestLog('itemised rows → expected: none, actual: ${find.byType(BillRow).evaluate().length}');
      expect(find.byType(BillRow), findsNothing);
    });

    testWidgets('itemises wallet and remaining rows for a split payment', (
      tester,
    ) async {
      printTestDivider('itemises wallet and remaining rows for a split payment');
      await pumpSummary(
        tester,
        PaymentBreakdown.compute(
          walletAmount: 100,
          remainingAmount: 146,
          paymentMethod: 'COD',
        ),
      );

      printTestLog('itemised rows → expected: 2, actual: ${find.byType(BillRow).evaluate().length}');
      expect(find.byType(BillRow), findsNWidgets(2));
      printTestLog('total label → expected: "${LanguageLabelKeys.total}" visible');
      expect(find.text(LanguageLabelKeys.total), findsOneWidget);
      printTestLog('total amount → expected: "₹246" visible');
      expect(find.text('₹246'), findsOneWidget);
      printTestLog('wallet row → expected: "₹100" visible');
      expect(find.text('₹100'), findsOneWidget);
      // Twice on purpose: once as the itemised remaining row, once inside the
      // collect-cash callout below it — this COD half is still to be collected.
      printTestLog('remaining amount → expected: 2 occurrences, actual: ${find.text('₹146').evaluate().length}');
      expect(find.text('₹146'), findsNWidgets(2));
    });

    testWidgets('labels a fully wallet-paid order as such', (tester) async {
      printTestDivider('labels a fully wallet-paid order as such');
      await pumpSummary(tester, PaymentBreakdown.compute(walletAmount: 103.5));

      printTestLog('label → expected: "${LanguageLabelKeys.paidFullyByWallet}" visible');
      expect(find.text(LanguageLabelKeys.paidFullyByWallet), findsOneWidget);
      printTestLog('amount → expected: "₹104" visible');
      expect(find.text('₹104'), findsOneWidget);
    });

    testWidgets('raises the collect-cash callout for an undelivered COD order', (
      tester,
    ) async {
      printTestDivider('raises the collect-cash callout for an undelivered COD order');
      await pumpSummary(
        tester,
        PaymentBreakdown.compute(remainingAmount: 910.35, paymentMethod: 'COD'),
      );

      printTestLog(
        'callout → expected: 1, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsOneWidget);
    });

    testWidgets('drops the callout once the order is delivered', (tester) async {
      printTestDivider('drops the callout once the order is delivered');
      await pumpSummary(
        tester,
        PaymentBreakdown.compute(
          remainingAmount: 910.35,
          paymentMethod: 'COD',
          isDelivered: true,
        ),
      );

      printTestLog(
        'callout → expected: absent, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsNothing);
    });
  });

  group('CollectFromCustomerCallout', () {
    testWidgets('names the amount the rider must collect', (tester) async {
      printTestDivider('names the amount the rider must collect');
      await tester.pumpWidget(
        pumpTestWidget(
          CollectFromCustomerCallout(
            breakdown: PaymentBreakdown.compute(
              remainingAmount: 910.35,
              paymentMethod: 'COD',
            ),
            symbol: '₹',
          ),
        ),
      );
      await tester.pump();

      printTestLog('label → expected: "${LanguageLabelKeys.collectFromCustomer}" visible');
      expect(find.text(LanguageLabelKeys.collectFromCustomer), findsOneWidget);
      // Rounded for display; the exact figure lives on the breakdown.
      printTestLog('amount → expected: "₹910" visible');
      expect(find.text('₹910'), findsOneWidget);
    });

    testWidgets('shows only the remaining amount when a wallet part-paid it', (
      tester,
    ) async {
      printTestDivider('shows only the remaining amount when a wallet part-paid it');
      // The wallet share is already settled, so the rider collects the rest.
      await tester.pumpWidget(
        pumpTestWidget(
          CollectFromCustomerCallout(
            breakdown: PaymentBreakdown.compute(
              walletAmount: 100,
              remainingAmount: 146,
              paymentMethod: 'COD',
            ),
            symbol: '₹',
          ),
        ),
      );
      await tester.pump();

      printTestLog('amount → expected: "₹146", not the ₹246 total');
      expect(find.text('₹146'), findsOneWidget);
      expect(find.text('₹246'), findsNothing);
    });
  });
}
