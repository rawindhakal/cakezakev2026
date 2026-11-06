import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/widgets/active_status_chart.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_stat_column.dart';
import 'package:deliveryboy/features/home/widgets/order_status_grid.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  StatusBreakdown breakdown(String name, int count) =>
      StatusBreakdown.fromJson({'name': name, 'count': count});

  Future<void> pumpGrid(
    WidgetTester tester, {
    required List<StatusBreakdown> statuses,
    int completed = 0,
    int quick = 0,
    int ecommerce = 0,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(
          child: OrderStatusGrid(
            statuses: statuses,
            completed: completed,
            quick: quick,
            ecommerce: ecommerce,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders one chart entry per status returned by the API', (
    tester,
  ) async {
    printTestDivider('renders one chart entry per status returned by the API');
    await pumpGrid(
      tester,
      statuses: [
        breakdown('Out for Pickup', 3),
        breakdown('Delivered', 12),
        breakdown('Picked Up', 5),
      ],
    );

    final chart = tester.widget<ActiveStatusChart>(
      find.byType(ActiveStatusChart),
    );
    printTestLog('chart items → expected: 3, actual: ${chart.items.length}');
    expect(chart.items.length, 3);
    printTestLog('first entry → expected: Out for Pickup=3, actual: ${chart.items.first}');
    expect(chart.items.first.key, 'Out for Pickup');
    expect(chart.items.first.value, 3);
  });

  testWidgets('falls back to a single completed entry when no statuses come back', (
    tester,
  ) async {
    printTestDivider(
      'falls back to a single completed entry when no statuses come back',
    );
    await pumpGrid(tester, statuses: const [], completed: 7);

    final chart = tester.widget<ActiveStatusChart>(
      find.byType(ActiveStatusChart),
    );
    printTestLog('chart items → expected: 1, actual: ${chart.items.length}');
    expect(chart.items.length, 1);
    // Translations aren't loaded in tests, so the label falls back to its key.
    printTestLog('fallback entry → expected: ${LanguageLabelKeys.completed}=7, actual: ${chart.items.first}');
    expect(chart.items.first.key, LanguageLabelKeys.completed);
    expect(chart.items.first.value, 7);
  });

  testWidgets('defaults a missing status name or count to empty/zero', (
    tester,
  ) async {
    printTestDivider('defaults a missing status name or count to empty/zero');
    await pumpGrid(
      tester,
      statuses: [StatusBreakdown.fromJson(const <String, dynamic>{})],
    );

    final chart = tester.widget<ActiveStatusChart>(
      find.byType(ActiveStatusChart),
    );
    printTestLog('entry → expected: ""=0, actual: ${chart.items.first}');
    expect(chart.items.first.key, '');
    expect(chart.items.first.value, 0);
  });

  testWidgets('shows the quick and ecommerce order counts as a separate dimension', (
    tester,
  ) async {
    printTestDivider(
      'shows the quick and ecommerce order counts as a separate dimension',
    );
    await pumpGrid(
      tester,
      statuses: [breakdown('Delivered', 12)],
      quick: 8,
      ecommerce: 4,
    );

    final columns = tester
        .widgetList<DashboardStatColumn>(find.byType(DashboardStatColumn))
        .toList();
    printTestLog('stat columns → expected: 2, actual: ${columns.length}');
    expect(columns.length, 2);
    printTestLog('quick value → expected: "8", actual: "${columns[0].value}"');
    expect(columns[0].value, '8');
    printTestLog('ecommerce value → expected: "4", actual: "${columns[1].value}"');
    expect(columns[1].value, '4');
    printTestLog('ecommerce alignEnd → expected: true, actual: ${columns[1].alignEnd}');
    expect(columns[1].alignEnd, isTrue);
  });

  testWidgets('renders with all-zero counts without dividing by zero', (
    tester,
  ) async {
    printTestDivider('renders with all-zero counts without dividing by zero');
    // A brand-new rider has nothing in any bucket — the chart still has to
    // lay out rather than throwing on a zero total.
    await pumpGrid(tester, statuses: [breakdown('Delivered', 0)]);

    printTestLog(
      'chart → expected: rendered, actual: ${find.byType(ActiveStatusChart).evaluate().length}',
    );
    expect(find.byType(ActiveStatusChart), findsOneWidget);
  });
}
