import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/salary/models/salary_model.dart';
import 'package:deliveryboy/features/salary/widgets/salary_card.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(WidgetTester tester, SalaryModel item) async {
    await tester.pumpWidget(
      pumpTestWidget(SingleChildScrollView(child: SalaryCard(item: item))),
    );
    await tester.pump();
  }

  testWidgets('shows the id and paidOn from a full entry', (tester) async {
    printTestDivider('shows the id and paidOn from a full entry');
    await pumpCard(
      tester,
      SalaryModel.fromJson({
        'id': 701,
        'amount': 25000.00,
        'note': 'August 2026 salary',
        'paid_on': '2026-08-01',
        'currency': '₹',
      }),
    );

    printTestLog(
      'id → expected: "${AppConstants.hashSymbol}701" visible in the id line',
    );
    expect(find.textContaining('701'), findsWidgets);
    printTestLog('paidOn → expected: "2026-08-01" visible');
    expect(find.text('2026-08-01'), findsOneWidget);
    printTestLog('amount → expected: "+ ₹25000.0" visible');
    expect(find.text('+ ₹25000.0'), findsOneWidget);
    printTestLog('paid label → expected: "${LanguageLabelKeys.paid}" visible');
    expect(find.text(LanguageLabelKeys.paid), findsOneWidget);
  });

  testWidgets('falls back to an em dash when id is null', (tester) async {
    printTestDivider('falls back to an em dash when id is null');
    await pumpCard(tester, SalaryModel.fromJson(const {}));

    printTestLog('id placeholder → expected: "—" visible in the id line');
    expect(find.textContaining('—'), findsWidgets);
  });

  testWidgets('falls back to an em dash when paidOn is empty', (tester) async {
    printTestDivider('falls back to an em dash when paidOn is empty');
    // fromJson defaults paidOn to '' when absent — the card itself only
    // falls back to '—' for a real null, so build the model directly to
    // exercise that branch.
    final item = SalaryModel(id: 1, paidOn: null);
    await pumpCard(tester, item);

    printTestLog('paidOn placeholder → expected: "—" visible');
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('falls back to a 0 amount when amount is null', (tester) async {
    printTestDivider('falls back to a 0 amount when amount is null');
    final item = SalaryModel(id: 1, amount: null, currency: null);
    await pumpCard(tester, item);

    printTestLog('amount → expected: "+ 0" visible');
    expect(find.text('+ 0'), findsOneWidget);
  });

  group('tap behavior driven by hasSalaryDetail', () {
    testWidgets('tapping a card with a note opens the detail sheet', (
      tester,
    ) async {
      printTestDivider('tapping a card with a note opens the detail sheet');
      await pumpCard(
        tester,
        SalaryModel.fromJson({'id': 1, 'note': 'Includes overtime bonus'}),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      printTestLog(
        'detail note → expected: "Includes overtime bonus" visible, actual: ${find.text('Includes overtime bonus').evaluate().length}',
      );
      expect(find.text('Includes overtime bonus'), findsOneWidget);
    });

    testWidgets('a card with no note is not tappable — onTap is null, not a no-op', (
      tester,
    ) async {
      printTestDivider(
        'a card with no note is not tappable — onTap is null, not a no-op',
      );
      await pumpCard(tester, SalaryModel.fromJson(const {'id': 1}));

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      printTestLog('onTap → expected: null, actual: ${inkWell.onTap}');
      expect(inkWell.onTap, isNull);
    });

    testWidgets('a card whose note is the literal "null" string is not tappable', (
      tester,
    ) async {
      printTestDivider(
        'a card whose note is the literal "null" string is not tappable',
      );
      await pumpCard(
        tester,
        SalaryModel.fromJson(const {'id': 1, 'note': 'null'}),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      printTestLog('onTap → expected: null, actual: ${inkWell.onTap}');
      expect(inkWell.onTap, isNull);
    });
  });
}
