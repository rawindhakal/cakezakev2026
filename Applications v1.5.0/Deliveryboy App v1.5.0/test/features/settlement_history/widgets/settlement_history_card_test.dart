import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  // The card formats created_at through AppDateFormatter, which reads the
  // server-provided format out of SettingsHiveBox.
  setUp(() => HiveTestHelper.setUp(settingsBox));
  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(WidgetTester tester, SettlementHistoryData item) async {
    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(child: SettlementHistoryCard(item: item)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the id line, signed amount and capitalised type for a credit', (
    tester,
  ) async {
    printTestDivider(
      'shows the id line, signed amount and capitalised type for a credit',
    );
    await pumpCard(
      tester,
      SettlementHistoryData.fromJson(const {
        'id': '901',
        'entry_type': 'delivery_commission',
        'type': 'credit',
        'amount': '150.75',
        'currency': '₹',
        'created_at': '2026-08-17 12:00:00',
      }),
    );

    printTestLog(
      'id line → expected: "${LanguageLabelKeys.settlementId} ${AppConstants.hashSymbol}901" visible',
    );
    expect(
      find.text(
        '${LanguageLabelKeys.settlementId} ${AppConstants.hashSymbol}901',
      ),
      findsOneWidget,
    );
    printTestLog('amount → expected: "+ ₹150.75" visible');
    expect(find.text('+ ₹150.75'), findsOneWidget);
    printTestLog('type → expected: "Credit" visible');
    expect(find.text('Credit'), findsOneWidget);
  });

  testWidgets('a debit renders a minus sign, not a plus', (tester) async {
    printTestDivider('a debit renders a minus sign, not a plus');
    await pumpCard(
      tester,
      SettlementHistoryData.fromJson(const {
        'id': '902',
        'type': 'debit',
        'amount': 500,
        'currency': '₹',
      }),
    );

    printTestLog('amount → expected: "- ₹500.0" visible');
    expect(find.text('- ₹500.0'), findsOneWidget);
    printTestLog('type → expected: "Debit" visible');
    expect(find.text('Debit'), findsOneWidget);
  });

  testWidgets('an unknown type falls back to a debit sign — only "credit" is a credit', (
    tester,
  ) async {
    printTestDivider(
      'an unknown type falls back to a debit sign — only "credit" is a credit',
    );
    await pumpCard(
      tester,
      SettlementHistoryData.fromJson(const {
        'id': '903',
        'type': 'refund',
        'amount': 10,
        'currency': '₹',
      }),
    );

    printTestLog('amount → expected: "- ₹10.0" visible');
    expect(find.text('- ₹10.0'), findsOneWidget);
    printTestLog('type → expected: "Refund" visible');
    expect(find.text('Refund'), findsOneWidget);
  });

  testWidgets('falls back to an em dash when id is null', (tester) async {
    printTestDivider('falls back to an em dash when id is null');
    await pumpCard(tester, SettlementHistoryData.fromJson(const {}));

    printTestLog(
      'id line → expected: "${LanguageLabelKeys.settlementId} ${AppConstants.hashSymbol}—" visible',
    );
    expect(
      find.text('${LanguageLabelKeys.settlementId} ${AppConstants.hashSymbol}—'),
      findsOneWidget,
    );
  });

  testWidgets('falls back to an em dash when type is null', (tester) async {
    printTestDivider('falls back to an em dash when type is null');
    await pumpCard(tester, SettlementHistoryData.fromJson(const {'id': '901'}));

    printTestLog('type placeholder → expected: "—" visible');
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('renders a 0 amount with no currency prefix when both are absent', (
    tester,
  ) async {
    printTestDivider(
      'renders a 0 amount with no currency prefix when both are absent',
    );
    // fromJson defaults amount to 0.0 (never null), so an absent amount
    // renders as "0.0" rather than hitting the card's own `?? 0` fallback.
    await pumpCard(tester, SettlementHistoryData.fromJson(const {'id': '901'}));

    printTestLog('amount → expected: "- 0.0" visible');
    expect(find.text('- 0.0'), findsOneWidget);
  });

  testWidgets('falls back to a 0 amount when the model is built with a null amount', (
    tester,
  ) async {
    printTestDivider(
      'falls back to a 0 amount when the model is built with a null amount',
    );
    // The card's `item.amount ?? 0` branch is only reachable by building the
    // model directly (fromJson defaults amount to 0.0, never null). The
    // literal `0` still prints as "0.0": `??` against a `double?` types the
    // right operand as a double, so it is coerced before interpolation.
    await pumpCard(
      tester,
      SettlementHistoryData(id: '901', type: 'credit', amount: null),
    );

    printTestLog('amount → expected: "+ 0.0" visible');
    expect(find.text('+ 0.0'), findsOneWidget);
  });

  testWidgets('an unparseable created_at is shown through as-is', (tester) async {
    printTestDivider('an unparseable created_at is shown through as-is');
    await pumpCard(
      tester,
      SettlementHistoryData.fromJson(const {
        'id': '901',
        'created_at': 'not a date',
      }),
    );

    printTestLog('created_at → expected: "not a date" visible');
    expect(find.text('not a date'), findsOneWidget);
  });

  testWidgets('a null created_at renders as an empty date, not the word "null"', (
    tester,
  ) async {
    printTestDivider(
      'a null created_at renders as an empty date, not the word "null"',
    );
    await pumpCard(tester, SettlementHistoryData.fromJson(const {'id': '901'}));

    printTestLog('created_at → expected: no "null" text, actual: ${find.text('null').evaluate().length}');
    expect(find.text('null'), findsNothing);
  });

  testWidgets('tapping the card opens the detail sheet', (tester) async {
    printTestDivider('tapping the card opens the detail sheet');
    await pumpCard(
      tester,
      SettlementHistoryData.fromJson(const {
        'id': '901',
        'entry_type': 'delivery_commission',
        'type': 'credit',
        'amount': 150.75,
        'opening_balance': 1200,
        'closing_balance': 1350.75,
        'currency': '₹',
        'message': 'Commission for order #1006',
      }),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog(
      'sheet title → expected: "${LanguageLabelKeys.transactionDetail}" visible',
    );
    expect(find.text(LanguageLabelKeys.transactionDetail), findsOneWidget);
    printTestLog('detail message → expected: "Commission for order #1006" visible');
    expect(find.text('Commission for order #1006'), findsOneWidget);
  });

  testWidgets('every card is tappable — even one with no message at all', (
    tester,
  ) async {
    printTestDivider('every card is tappable — even one with no message at all');
    // Unlike SalaryCard, this card has no "is there detail to show?" guard:
    // the sheet always has opening/closing balance to show, so onTap is
    // never null.
    await pumpCard(tester, SettlementHistoryData.fromJson(const {'id': '901'}));

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    printTestLog('onTap → expected: non-null, actual: ${inkWell.onTap}');
    expect(inkWell.onTap, isNotNull);
  });
}
