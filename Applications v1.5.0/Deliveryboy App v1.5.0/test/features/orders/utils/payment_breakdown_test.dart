import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  /// The label getters need a BuildContext for translation. Translations
  /// aren't loaded under `flutter test`, so every label resolves to its raw
  /// LanguageLabelKeys value.
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  group('compute', () {
    test('keeps positive wallet and remaining amounts', () {
      printTestDivider('compute keeps positive wallet and remaining amounts');
      final breakdown = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 120.5,
        paymentMethod: 'COD',
      );

      printTestLog('wallet → expected: 50.0, actual: ${breakdown.wallet}');
      expect(breakdown.wallet, 50.0);
      printTestLog('remaining → expected: 120.5, actual: ${breakdown.remaining}');
      expect(breakdown.remaining, 120.5);
      printTestLog('isCod → expected: true, actual: ${breakdown.isCod}');
      expect(breakdown.isCod, isTrue);
    });

    test('floors null, zero and negative amounts to zero', () {
      printTestDivider('compute floors null, zero and negative amounts to zero');
      final breakdown = PaymentBreakdown.compute(
        walletAmount: null,
        remainingAmount: -10,
        refundAmount: 0,
      );

      printTestLog('wallet → expected: 0.0, actual: ${breakdown.wallet}');
      expect(breakdown.wallet, 0.0);
      printTestLog('remaining → expected: 0.0, actual: ${breakdown.remaining}');
      expect(breakdown.remaining, 0.0);
      printTestLog('refundAmount → expected: 0.0, actual: ${breakdown.refundAmount}');
      expect(breakdown.refundAmount, 0.0);
    });

    test('detects COD case-insensitively and ignores surrounding spaces', () {
      printTestDivider(
        'compute detects COD case-insensitively and ignores surrounding spaces',
      );
      for (final method in ['cod', 'COD', ' Cod ']) {
        final breakdown = PaymentBreakdown.compute(paymentMethod: method);
        printTestLog('"$method" → expected isCod: true, actual: ${breakdown.isCod}');
        expect(breakdown.isCod, isTrue);
      }

      final online = PaymentBreakdown.compute(paymentMethod: 'Razorpay');
      printTestLog('"Razorpay" → expected isCod: false, actual: ${online.isCod}');
      expect(online.isCod, isFalse);
    });
  });

  group('flags', () {
    test('isCombined only when both wallet and a remaining amount are present', () {
      printTestDivider(
        'isCombined only when both wallet and a remaining amount are present',
      );
      final combined = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 100,
      );
      printTestLog('wallet+remaining → expected: true, actual: ${combined.isCombined}');
      expect(combined.isCombined, isTrue);

      final walletOnly = PaymentBreakdown.compute(walletAmount: 50);
      printTestLog('wallet only → expected: false, actual: ${walletOnly.isCombined}');
      expect(walletOnly.isCombined, isFalse);
      printTestLog(
        'wallet only isFullyPaidByWallet → expected: true, actual: ${walletOnly.isFullyPaidByWallet}',
      );
      expect(walletOnly.isFullyPaidByWallet, isTrue);

      final remainingOnly = PaymentBreakdown.compute(remainingAmount: 100);
      printTestLog('remaining only → expected: false, actual: ${remainingOnly.isCombined}');
      expect(remainingOnly.isCombined, isFalse);
    });

    test('totalAmount sums wallet and remaining', () {
      printTestDivider('totalAmount sums wallet and remaining');
      final breakdown = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 120.5,
      );
      printTestLog('totalAmount → expected: 170.5, actual: ${breakdown.totalAmount}');
      expect(breakdown.totalAmount, 170.5);
      printTestLog(
        'combinedTotalAmount → expected: 170.5, actual: ${breakdown.combinedTotalAmount}',
      );
      expect(breakdown.combinedTotalAmount, 170.5);
    });
  });

  group('collectAmount', () {
    test('is the remaining amount for an undelivered COD order', () {
      printTestDivider('collectAmount is the remaining amount for an undelivered COD order');
      final breakdown = PaymentBreakdown.compute(
        remainingAmount: 250,
        paymentMethod: 'COD',
      );

      printTestLog('collectAmount → expected: 250.0, actual: ${breakdown.collectAmount}');
      expect(breakdown.collectAmount, 250.0);
      printTestLog('mustCollectCash → expected: true, actual: ${breakdown.mustCollectCash}');
      expect(breakdown.mustCollectCash, isTrue);
    });

    test('is zero once the order has been delivered', () {
      printTestDivider('collectAmount is zero once the order has been delivered');
      // Cash was already taken at handover, so nothing is left to collect.
      final breakdown = PaymentBreakdown.compute(
        remainingAmount: 250,
        paymentMethod: 'COD',
        isDelivered: true,
      );

      printTestLog('collectAmount → expected: 0.0, actual: ${breakdown.collectAmount}');
      expect(breakdown.collectAmount, 0.0);
      printTestLog('mustCollectCash → expected: false, actual: ${breakdown.mustCollectCash}');
      expect(breakdown.mustCollectCash, isFalse);
    });

    test('is zero once a refund has been issued', () {
      printTestDivider('collectAmount is zero once a refund has been issued');
      final breakdown = PaymentBreakdown.compute(
        remainingAmount: 250,
        paymentMethod: 'COD',
        refundAmount: 100,
      );

      printTestLog('collectAmount → expected: 0.0, actual: ${breakdown.collectAmount}');
      expect(breakdown.collectAmount, 0.0);
    });

    test('is zero for a prepaid order', () {
      printTestDivider('collectAmount is zero for a prepaid order');
      final breakdown = PaymentBreakdown.compute(
        remainingAmount: 250,
        paymentMethod: 'Razorpay',
      );

      printTestLog('collectAmount → expected: 0.0, actual: ${breakdown.collectAmount}');
      expect(breakdown.collectAmount, 0.0);
    });

    test('is zero when the wallet covered the whole order', () {
      printTestDivider('collectAmount is zero when the wallet covered the whole order');
      final breakdown = PaymentBreakdown.compute(
        walletAmount: 250,
        paymentMethod: 'COD',
      );

      printTestLog('collectAmount → expected: 0.0, actual: ${breakdown.collectAmount}');
      expect(breakdown.collectAmount, 0.0);
    });
  });

  group('labels', () {
    testWidgets('methodName names COD, the raw gateway, or a generic Online', (
      tester,
    ) async {
      printTestDivider('methodName names COD, the raw gateway, or a generic Online');
      final context = await pumpContext(tester);

      final cod = PaymentBreakdown.compute(paymentMethod: 'COD');
      printTestLog('COD → expected: "${LanguageLabelKeys.cod}", actual: "${cod.methodName(context)}"');
      expect(cod.methodName(context), LanguageLabelKeys.cod);

      final gateway = PaymentBreakdown.compute(paymentMethod: 'Razorpay');
      printTestLog('Razorpay → expected: "Razorpay", actual: "${gateway.methodName(context)}"');
      expect(gateway.methodName(context), 'Razorpay');

      // No method name at all falls back to the generic "Online" label.
      final blank = PaymentBreakdown.compute(paymentMethod: '  ');
      printTestLog(
        'blank → expected: "${LanguageLabelKeys.online}", actual: "${blank.methodName(context)}"',
      );
      expect(blank.methodName(context), LanguageLabelKeys.online);

      final none = PaymentBreakdown.compute();
      printTestLog(
        'null → expected: "${LanguageLabelKeys.online}", actual: "${none.methodName(context)}"',
      );
      expect(none.methodName(context), LanguageLabelKeys.online);
    });

    testWidgets('walletLabel reads "paid via wallet"', (tester) async {
      printTestDivider('walletLabel reads "paid via wallet"');
      final context = await pumpContext(tester);
      final breakdown = PaymentBreakdown.compute(walletAmount: 50);

      final expected =
          '${LanguageLabelKeys.paidVia} ${LanguageLabelKeys.wallet}';
      printTestLog('walletLabel → expected: "$expected", actual: "${breakdown.walletLabel(context)}"');
      expect(breakdown.walletLabel(context), expected);
    });

    testWidgets('remainingLabel says "pay via" before delivery and "paid via" after', (
      tester,
    ) async {
      printTestDivider(
        'remainingLabel says "pay via" before delivery and "paid via" after',
      );
      final context = await pumpContext(tester);

      final pending = PaymentBreakdown.compute(
        remainingAmount: 100,
        paymentMethod: 'COD',
      );
      final pendingExpected =
          '${LanguageLabelKeys.payVia} ${LanguageLabelKeys.cod}';
      printTestLog(
        'undelivered COD → expected: "$pendingExpected", actual: "${pending.remainingLabel(context)}"',
      );
      expect(pending.remainingLabel(context), pendingExpected);

      final delivered = PaymentBreakdown.compute(
        remainingAmount: 100,
        paymentMethod: 'COD',
        isDelivered: true,
      );
      final deliveredExpected =
          '${LanguageLabelKeys.paidVia} ${LanguageLabelKeys.cod}';
      printTestLog(
        'delivered COD → expected: "$deliveredExpected", actual: "${delivered.remainingLabel(context)}"',
      );
      expect(delivered.remainingLabel(context), deliveredExpected);

      // A prepaid order is already paid, so it never says "pay via".
      final prepaid = PaymentBreakdown.compute(
        remainingAmount: 100,
        paymentMethod: 'Razorpay',
      );
      printTestLog(
        'prepaid → expected: "${LanguageLabelKeys.paidVia} Razorpay", actual: "${prepaid.remainingLabel(context)}"',
      );
      expect(
        prepaid.remainingLabel(context),
        '${LanguageLabelKeys.paidVia} Razorpay',
      );
    });

    testWidgets('totalLabel is a plain Total only when rows are itemized above it', (
      tester,
    ) async {
      printTestDivider(
        'totalLabel is a plain Total only when rows are itemized above it',
      );
      final context = await pumpContext(tester);

      final combined = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 100,
        paymentMethod: 'COD',
      );
      printTestLog(
        'combined → expected: "${LanguageLabelKeys.total}", actual: "${combined.totalLabel(context)}"',
      );
      expect(combined.totalLabel(context), LanguageLabelKeys.total);

      final walletOnly = PaymentBreakdown.compute(walletAmount: 50);
      printTestLog(
        'wallet only → expected: "${LanguageLabelKeys.paidFullyByWallet}", actual: "${walletOnly.totalLabel(context)}"',
      );
      expect(
        walletOnly.totalLabel(context),
        LanguageLabelKeys.paidFullyByWallet,
      );

      final codOnly = PaymentBreakdown.compute(
        remainingAmount: 100,
        paymentMethod: 'COD',
      );
      printTestLog(
        'COD only → expected: "${LanguageLabelKeys.payVia} ${LanguageLabelKeys.cod}", actual: "${codOnly.totalLabel(context)}"',
      );
      expect(
        codOnly.totalLabel(context),
        '${LanguageLabelKeys.payVia} ${LanguageLabelKeys.cod}',
      );

      // Nothing paid either way — a free order still needs a Total row.
      final empty = PaymentBreakdown.compute();
      printTestLog(
        'nothing paid → expected: "${LanguageLabelKeys.total}", actual: "${empty.totalLabel(context)}"',
      );
      expect(empty.totalLabel(context), LanguageLabelKeys.total);
    });

    testWidgets('combinedTotalLabel names both methods on a single-row card', (
      tester,
    ) async {
      printTestDivider('combinedTotalLabel names both methods on a single-row card');
      final context = await pumpContext(tester);

      final combinedCod = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 100,
        paymentMethod: 'COD',
      );
      final expectedCod =
          '${LanguageLabelKeys.payVia} ${LanguageLabelKeys.wallet}+${LanguageLabelKeys.cod}';
      printTestLog(
        'wallet + undelivered COD → expected: "$expectedCod", actual: "${combinedCod.combinedTotalLabel(context)}"',
      );
      expect(combinedCod.combinedTotalLabel(context), expectedCod);

      final combinedDelivered = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 100,
        paymentMethod: 'COD',
        isDelivered: true,
      );
      final expectedDelivered =
          '${LanguageLabelKeys.paidVia} ${LanguageLabelKeys.wallet}+${LanguageLabelKeys.cod}';
      printTestLog(
        'wallet + delivered COD → expected: "$expectedDelivered", actual: "${combinedDelivered.combinedTotalLabel(context)}"',
      );
      expect(combinedDelivered.combinedTotalLabel(context), expectedDelivered);

      final combinedGateway = PaymentBreakdown.compute(
        walletAmount: 50,
        remainingAmount: 100,
        paymentMethod: 'Razorpay',
      );
      printTestLog(
        'wallet + gateway → expected: "${LanguageLabelKeys.paidVia} ${LanguageLabelKeys.wallet}+Razorpay", actual: "${combinedGateway.combinedTotalLabel(context)}"',
      );
      expect(
        combinedGateway.combinedTotalLabel(context),
        '${LanguageLabelKeys.paidVia} ${LanguageLabelKeys.wallet}+Razorpay',
      );
    });

    testWidgets('combinedTotalLabel falls back to a single method when there is no wallet', (
      tester,
    ) async {
      printTestDivider(
        'combinedTotalLabel falls back to a single method when there is no wallet',
      );
      final context = await pumpContext(tester);

      final codOnly = PaymentBreakdown.compute(
        remainingAmount: 100,
        paymentMethod: 'COD',
      );
      printTestLog(
        'COD only → expected: "${LanguageLabelKeys.payVia} ${LanguageLabelKeys.cod}", actual: "${codOnly.combinedTotalLabel(context)}"',
      );
      expect(
        codOnly.combinedTotalLabel(context),
        '${LanguageLabelKeys.payVia} ${LanguageLabelKeys.cod}',
      );

      final walletOnly = PaymentBreakdown.compute(walletAmount: 50);
      printTestLog(
        'wallet only → expected: "${LanguageLabelKeys.paidFullyByWallet}", actual: "${walletOnly.combinedTotalLabel(context)}"',
      );
      expect(
        walletOnly.combinedTotalLabel(context),
        LanguageLabelKeys.paidFullyByWallet,
      );

      final empty = PaymentBreakdown.compute();
      printTestLog(
        'nothing paid → expected: "${LanguageLabelKeys.total}", actual: "${empty.combinedTotalLabel(context)}"',
      );
      expect(empty.combinedTotalLabel(context), LanguageLabelKeys.total);
    });
  });
}
