import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/salary/widgets/salary_detail_sheet.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('hasSalaryDetail', () {
    test('true when note is present', () {
      printTestDivider('hasSalaryDetail true when note is present');
      final result = hasSalaryDetail('Includes overtime bonus');
      printTestLog('result → expected: true, actual: $result');
      expect(result, isTrue);
    });

    test('false for null, empty, whitespace, and the literal "null" string', () {
      printTestDivider(
        'hasSalaryDetail false for null, empty, whitespace, and the literal "null" string',
      );
      printTestLog('null → expected: false');
      expect(hasSalaryDetail(null), isFalse);
      printTestLog('empty → expected: false');
      expect(hasSalaryDetail(''), isFalse);
      printTestLog('whitespace → expected: false');
      expect(hasSalaryDetail('   '), isFalse);
      printTestLog('"null"/"NULL" → expected: false (case-insensitive)');
      expect(hasSalaryDetail('null'), isFalse);
      expect(hasSalaryDetail('NULL'), isFalse);
    });
  });

  Future<void> pumpSheetTrigger(WidgetTester tester, String note) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSalaryDetailSheet(context, note),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the message label and the note text', (tester) async {
    printTestDivider('shows the message label and the note text');
    await pumpSheetTrigger(tester, 'Includes overtime bonus');

    printTestLog(
      'title → expected: "${LanguageLabelKeys.transactionDetail}" visible',
    );
    expect(find.text(LanguageLabelKeys.transactionDetail), findsOneWidget);
    printTestLog('message label → expected: "${LanguageLabelKeys.message}" visible');
    expect(find.text(LanguageLabelKeys.message), findsOneWidget);
    printTestLog('note text → expected: "Includes overtime bonus" visible');
    expect(find.text('Includes overtime bonus'), findsOneWidget);
  });

  testWidgets('trims the note before showing it', (tester) async {
    printTestDivider('trims the note before showing it');
    await pumpSheetTrigger(tester, '  Includes overtime bonus  ');

    printTestLog('trimmed note → expected: "Includes overtime bonus" visible');
    expect(find.text('Includes overtime bonus'), findsOneWidget);
  });
}
