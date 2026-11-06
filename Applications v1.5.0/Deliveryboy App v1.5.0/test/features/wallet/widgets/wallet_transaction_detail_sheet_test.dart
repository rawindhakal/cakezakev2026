import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_transaction_detail_sheet.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('hasWalletTransactionDetail', () {
    test('true when message is present', () {
      printTestDivider('hasWalletTransactionDetail true when message is present');
      final result = hasWalletTransactionDetail(message: 'hi', remark: null);
      printTestLog('result → expected: true, actual: $result');
      expect(result, isTrue);
    });

    test('true when only remark is present', () {
      printTestDivider('hasWalletTransactionDetail true when only remark is present');
      final result = hasWalletTransactionDetail(message: null, remark: 'ok');
      printTestLog('result → expected: true, actual: $result');
      expect(result, isTrue);
    });

    test('false for null, empty, and the literal "null" string', () {
      printTestDivider(
        'hasWalletTransactionDetail false for null, empty, and the literal "null" string',
      );
      expect(hasWalletTransactionDetail(message: null, remark: null), isFalse);
      expect(hasWalletTransactionDetail(message: '', remark: '  '), isFalse);
      printTestLog('"null" string → expected: false');
      expect(
        hasWalletTransactionDetail(message: 'null', remark: 'NULL'),
        isFalse,
      );
    });
  });

  Future<void> pumpSheetTrigger(
    WidgetTester tester, {
    String? message,
    String? remark,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showWalletTransactionDetailSheet(
              context,
              message: message,
              remark: remark,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows both message and remark sections when both are present', (
    tester,
  ) async {
    printTestDivider('shows both message and remark sections when both are present');
    await pumpSheetTrigger(
      tester,
      message: 'Need cash for fuel',
      remark: 'Approved and processed',
    );

    printTestLog('message label → expected: visible');
    expect(find.text(LanguageLabelKeys.message), findsOneWidget);
    printTestLog('message value → expected: "Need cash for fuel" visible');
    expect(find.text('Need cash for fuel'), findsOneWidget);
    printTestLog('remark label → expected: visible');
    expect(find.text(LanguageLabelKeys.remarks), findsOneWidget);
    printTestLog('remark value → expected: "Approved and processed" visible');
    expect(find.text('Approved and processed'), findsOneWidget);
  });

  testWidgets('shows only the message section when remark is absent', (
    tester,
  ) async {
    printTestDivider('shows only the message section when remark is absent');
    await pumpSheetTrigger(tester, message: 'Need cash for fuel', remark: null);

    printTestLog('message label → expected: visible');
    expect(find.text(LanguageLabelKeys.message), findsOneWidget);
    printTestLog('remark label → expected: absent');
    expect(find.text(LanguageLabelKeys.remarks), findsNothing);
  });

  testWidgets('normalizes the literal "null" string to blank and hides that section', (
    tester,
  ) async {
    printTestDivider(
      'normalizes the literal "null" string to blank and hides that section',
    );
    await pumpSheetTrigger(tester, message: 'null', remark: 'Approved');

    printTestLog('message label → expected: absent (normalized to blank)');
    expect(find.text(LanguageLabelKeys.message), findsNothing);
    printTestLog('remark label → expected: visible');
    expect(find.text(LanguageLabelKeys.remarks), findsOneWidget);
  });
}
