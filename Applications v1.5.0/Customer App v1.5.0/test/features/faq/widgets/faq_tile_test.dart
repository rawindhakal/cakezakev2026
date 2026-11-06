import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/faq/models/faq_model.dart';
import 'package:customer/features/faq/widgets/faq_tile.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  FaqData faq({String question = 'How do I track my order?', String answer = 'Open Orders and tap any order.'}) =>
      FaqData.fromJson({'id': '1', 'question': question, 'answer': answer, 'lang': 'en'});

  testWidgets('shows the question and hides the answer collapsed by default', (
    tester,
  ) async {
    printTestDivider('shows the question and hides the answer collapsed by default');
    await tester.pumpWidget(pumpTestWidget(FaqTile(faq: faq())));

    printTestLog('question → expected: visible');
    expect(find.text('How do I track my order?'), findsOneWidget);
    printTestLog('answer → expected: hidden');
    expect(find.text('Open Orders and tap any order.'), findsNothing);
  });

  testWidgets('tapping expands and reveals the answer', (tester) async {
    printTestDivider('tapping expands and reveals the answer');
    await tester.pumpWidget(pumpTestWidget(FaqTile(faq: faq())));

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    printTestLog('answer → expected: visible after tap');
    expect(find.text('Open Orders and tap any order.'), findsOneWidget);
  });

  testWidgets('tapping again collapses and hides the answer', (tester) async {
    printTestDivider('tapping again collapses and hides the answer');
    await tester.pumpWidget(pumpTestWidget(FaqTile(faq: faq())));

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    printTestLog('answer → expected: hidden after second tap');
    expect(find.text('Open Orders and tap any order.'), findsNothing);
  });
}
