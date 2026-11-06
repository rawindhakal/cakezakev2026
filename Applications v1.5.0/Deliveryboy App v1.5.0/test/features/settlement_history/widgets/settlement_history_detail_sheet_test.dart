import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_detail_sheet.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpSheet(
    WidgetTester tester,
    SettlementHistoryData item, {
    String currencySymbol = '₹',
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSettlementHistoryDetailSheet(
              context,
              item,
              currencySymbol: currencySymbol,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // The sheet's children slide in; wait out the entrance animation before
    // asserting on what's hit-testable and laid out.
    await tester.pump(const Duration(seconds: 1));
  }

  SettlementHistoryData fullEntry() => SettlementHistoryData.fromJson(const {
    'id': '901',
    'entry_type': 'delivery_commission',
    'type': 'credit',
    'amount': 150.75,
    'opening_balance': 1200,
    'closing_balance': 1350.75,
    'currency': '₹',
    'message': 'Commission for order #1006',
  });

  testWidgets('shows the title, type, both balances and the message', (
    tester,
  ) async {
    printTestDivider('shows the title, type, both balances and the message');
    await pumpSheet(tester, fullEntry());

    printTestLog('title → expected: "${LanguageLabelKeys.transactionDetail}" visible');
    expect(find.text(LanguageLabelKeys.transactionDetail), findsOneWidget);
    printTestLog('type label → expected: "${LanguageLabelKeys.settlementType}" visible');
    expect(find.text(LanguageLabelKeys.settlementType), findsOneWidget);
    printTestLog('type value → expected: "delivery_commission" visible');
    expect(find.text('delivery_commission'), findsOneWidget);
    printTestLog(
      'opening label → expected: "${LanguageLabelKeys.openingBalance}" visible',
    );
    expect(find.text(LanguageLabelKeys.openingBalance), findsOneWidget);
    printTestLog('opening value → expected: "₹1200.0" visible');
    expect(find.text('₹1200.0'), findsOneWidget);
    printTestLog(
      'closing label → expected: "${LanguageLabelKeys.closingBalance}" visible',
    );
    expect(find.text(LanguageLabelKeys.closingBalance), findsOneWidget);
    printTestLog('closing value → expected: "₹1350.75" visible');
    expect(find.text('₹1350.75'), findsOneWidget);
    printTestLog('message label → expected: "${LanguageLabelKeys.message}" visible');
    expect(find.text(LanguageLabelKeys.message), findsOneWidget);
    printTestLog('message value → expected: "Commission for order #1006" visible');
    expect(find.text('Commission for order #1006'), findsOneWidget);
  });

  testWidgets('the currency symbol is prefixed onto both balances', (
    tester,
  ) async {
    printTestDivider('the currency symbol is prefixed onto both balances');
    await pumpSheet(tester, fullEntry(), currencySymbol: r'$');

    printTestLog(r'opening value → expected: "$1200.0" visible');
    expect(find.text(r'$1200.0'), findsOneWidget);
    printTestLog(r'closing value → expected: "$1350.75" visible');
    expect(find.text(r'$1350.75'), findsOneWidget);
  });

  testWidgets('balances still render as 0.0 on an entry with none', (
    tester,
  ) async {
    printTestDivider('balances still render as 0.0 on an entry with none');
    // fromJson defaults both balances to 0.0 rather than null, so the sheet
    // always has something to show — which is why the card has no
    // "is there detail?" guard around opening it.
    await pumpSheet(
      tester,
      SettlementHistoryData.fromJson(const {'id': '901'}),
    );

    printTestLog(
      'balance values → expected: 2 × "₹0.0", actual: ${find.text('₹0.0').evaluate().length}',
    );
    expect(find.text('₹0.0'), findsNWidgets(2));
  });

  group('the settlement type block is conditional on entry_type', () {
    testWidgets('hidden when entry_type is absent', (tester) async {
      printTestDivider('the settlement type block is hidden when entry_type is absent');
      await pumpSheet(
        tester,
        SettlementHistoryData.fromJson(const {'id': '901'}),
      );

      printTestLog(
        'type label → expected: absent, actual: ${find.text(LanguageLabelKeys.settlementType).evaluate().length}',
      );
      expect(find.text(LanguageLabelKeys.settlementType), findsNothing);
    });

    testWidgets('hidden when entry_type is whitespace only', (tester) async {
      printTestDivider(
        'the settlement type block is hidden when entry_type is whitespace only',
      );
      await pumpSheet(
        tester,
        SettlementHistoryData.fromJson(const {'id': '901', 'entry_type': '   '}),
      );

      printTestLog(
        'type label → expected: absent, actual: ${find.text(LanguageLabelKeys.settlementType).evaluate().length}',
      );
      expect(find.text(LanguageLabelKeys.settlementType), findsNothing);
    });

    testWidgets('shows the trimmed value when entry_type is padded', (
      tester,
    ) async {
      printTestDivider(
        'the settlement type block shows the trimmed value when entry_type is padded',
      );
      await pumpSheet(
        tester,
        SettlementHistoryData.fromJson(const {
          'id': '901',
          'entry_type': '  withdrawal  ',
        }),
      );

      printTestLog('type value → expected: "withdrawal" visible');
      expect(find.text('withdrawal'), findsOneWidget);
    });
  });

  group('the message block is conditional on a real message', () {
    testWidgets('hidden when message is absent', (tester) async {
      printTestDivider('the message block is hidden when message is absent');
      await pumpSheet(
        tester,
        SettlementHistoryData.fromJson(const {'id': '901'}),
      );

      printTestLog(
        'message label → expected: absent, actual: ${find.text(LanguageLabelKeys.message).evaluate().length}',
      );
      expect(find.text(LanguageLabelKeys.message), findsNothing);
    });

    testWidgets('hidden when message is whitespace only', (tester) async {
      printTestDivider('the message block is hidden when message is whitespace only');
      await pumpSheet(
        tester,
        SettlementHistoryData.fromJson(const {'id': '901', 'message': '   '}),
      );

      printTestLog(
        'message label → expected: absent, actual: ${find.text(LanguageLabelKeys.message).evaluate().length}',
      );
      expect(find.text(LanguageLabelKeys.message), findsNothing);
    });

    testWidgets('hidden when message is the literal "null" string, in any case', (
      tester,
    ) async {
      printTestDivider(
        'the message block is hidden when message is the literal "null" string, in any case',
      );
      for (final raw in ['null', 'NULL', 'Null']) {
        await pumpSheet(
          tester,
          SettlementHistoryData.fromJson({'id': '901', 'message': raw}),
        );
        printTestLog(
          'message label for "$raw" → expected: absent, actual: ${find.text(LanguageLabelKeys.message).evaluate().length}',
        );
        expect(find.text(LanguageLabelKeys.message), findsNothing);
      }
    });

    testWidgets('shows the trimmed message when one is present', (tester) async {
      printTestDivider('the message block shows the trimmed message when one is present');
      await pumpSheet(
        tester,
        SettlementHistoryData.fromJson(const {
          'id': '901',
          'message': '  Withdrawal to bank account  ',
        }),
      );

      printTestLog('message value → expected: "Withdrawal to bank account" visible');
      expect(find.text('Withdrawal to bank account'), findsOneWidget);
    });
  });
}
