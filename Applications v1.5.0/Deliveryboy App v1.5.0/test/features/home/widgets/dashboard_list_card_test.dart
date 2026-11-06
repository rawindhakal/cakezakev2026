import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_list_card.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(
    WidgetTester tester, {
    String? title,
    required List<DashboardListRow> rows,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(child: DashboardListCard(title: title, rows: rows)),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders every row as a label/value pair', (tester) async {
    printTestDivider('renders every row as a label/value pair');
    await pumpCard(
      tester,
      rows: const [
        DashboardListRow(label: 'Total Orders', value: '31'),
        DashboardListRow(label: 'Delivered', value: '25'),
        DashboardListRow(label: 'Cancelled', value: '0'),
      ],
    );

    for (final entry in {'Total Orders': '31', 'Delivered': '25', 'Cancelled': '0'}.entries) {
      printTestLog('row → expected: "${entry.key}" / "${entry.value}" visible');
      expect(find.text(entry.key), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('renders the title when one is given', (tester) async {
    printTestDivider('renders the title when one is given');
    await pumpCard(
      tester,
      title: 'Order Summary',
      rows: const [DashboardListRow(label: 'Total', value: '31')],
    );

    printTestLog('title → expected: "Order Summary" visible');
    expect(find.text('Order Summary'), findsOneWidget);
  });

  testWidgets('omits the title when it is null or empty', (tester) async {
    printTestDivider('omits the title when it is null or empty');
    await pumpCard(
      tester,
      title: '',
      rows: const [DashboardListRow(label: 'Total', value: '31')],
    );

    // Only the row's own label and value should be on screen.
    printTestLog('texts on screen → expected: 2, actual: ${find.byType(Text).evaluate().length}');
    expect(find.byType(Text), findsNWidgets(2));
  });

  testWidgets('shows a progress bar only for rows that carry a percent', (
    tester,
  ) async {
    printTestDivider('shows a progress bar only for rows that carry a percent');
    await pumpCard(
      tester,
      rows: const [
        DashboardListRow(label: 'Delivered', value: '25', percent: 0.8),
        DashboardListRow(label: 'Cancelled', value: '0'),
      ],
    );

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    printTestLog('progress bars → expected: 1, actual: ${bars.length}');
    expect(bars.length, 1);
    printTestLog('value → expected: 0.8, actual: ${bars.first.value}');
    expect(bars.first.value, 0.8);
  });

  testWidgets('clamps an out-of-range percent into 0..1', (tester) async {
    printTestDivider('clamps an out-of-range percent into 0..1');
    // A backend that reports more delivered than total would otherwise push
    // the indicator past its track.
    await pumpCard(
      tester,
      rows: const [
        DashboardListRow(label: 'Over', value: '120%', percent: 1.8),
        DashboardListRow(label: 'Under', value: '-5%', percent: -0.4),
      ],
    );

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    printTestLog('clamped high → expected: 1.0, actual: ${bars[0].value}');
    expect(bars[0].value, 1.0);
    printTestLog('clamped low  → expected: 0.0, actual: ${bars[1].value}');
    expect(bars[1].value, 0.0);
  });

  testWidgets('renders an empty card when there are no rows', (tester) async {
    printTestDivider('renders an empty card when there are no rows');
    await pumpCard(tester, title: 'Returns', rows: const []);

    printTestLog('title → expected: "Returns" visible');
    expect(find.text('Returns'), findsOneWidget);
    printTestLog(
      'progress bars → expected: 0, actual: ${find.byType(LinearProgressIndicator).evaluate().length}',
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
