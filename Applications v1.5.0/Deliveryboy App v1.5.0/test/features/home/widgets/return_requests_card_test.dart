import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_stat_column.dart';
import 'package:deliveryboy/features/home/widgets/return_requests_card.dart';
import 'package:deliveryboy/features/home/widgets/return_requests_pie_chart.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Returns returns({
    int total = 4,
    int completed = 3,
    int pending = 1,
    List<Map<String, dynamic>>? breakdown,
  }) => Returns.fromJson({
    'total': total,
    'completed': completed,
    'pending': pending,
    'breakdown': ?breakdown,
  });

  Future<void> pumpCard(WidgetTester tester, Returns data) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(child: ReturnRequestsCard(returns: data)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the donut chart when a status breakdown comes back', (
    tester,
  ) async {
    printTestDivider('shows the donut chart when a status breakdown comes back');
    await pumpCard(
      tester,
      returns(
        breakdown: const [
          {'status_id': 5, 'name': 'Out for Pickup', 'count': 2},
          {'status_id': 6, 'name': 'Received from Customer', 'count': 2},
        ],
      ),
    );

    printTestLog(
      'pie chart → expected: 1, actual: ${find.byType(ReturnRequestsPieChart).evaluate().length}',
    );
    expect(find.byType(ReturnRequestsPieChart), findsOneWidget);
  });

  testWidgets('falls back to a plain total row when there is no breakdown', (
    tester,
  ) async {
    printTestDivider('falls back to a plain total row when there is no breakdown');
    await pumpCard(tester, returns(total: 4));

    printTestLog(
      'pie chart → expected: absent, actual: ${find.byType(ReturnRequestsPieChart).evaluate().length}',
    );
    expect(find.byType(ReturnRequestsPieChart), findsNothing);
    // Translations aren't loaded in tests, so labels fall back to raw keys.
    printTestLog('fallback label → expected: "${LanguageLabelKeys.returnRequests}" visible');
    expect(find.text(LanguageLabelKeys.returnRequests), findsOneWidget);
    printTestLog('total → expected: "4" visible');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('treats an empty breakdown list the same as none at all', (
    tester,
  ) async {
    printTestDivider('treats an empty breakdown list the same as none at all');
    await pumpCard(tester, returns(breakdown: const []));

    printTestLog(
      'pie chart → expected: absent, actual: ${find.byType(ReturnRequestsPieChart).evaluate().length}',
    );
    expect(find.byType(ReturnRequestsPieChart), findsNothing);
  });

  testWidgets('always shows the completed and pending counts', (tester) async {
    printTestDivider('always shows the completed and pending counts');
    await pumpCard(tester, returns(completed: 3, pending: 1));

    final columns = tester
        .widgetList<DashboardStatColumn>(find.byType(DashboardStatColumn))
        .toList();
    printTestLog('stat columns → expected: 2, actual: ${columns.length}');
    expect(columns.length, 2);
    printTestLog('completed → expected: "3", actual: "${columns[0].value}"');
    expect(columns[0].value, '3');
    printTestLog('pending   → expected: "1", actual: "${columns[1].value}"');
    expect(columns[1].value, '1');
    printTestLog('pending alignEnd → expected: true, actual: ${columns[1].alignEnd}');
    expect(columns[1].alignEnd, isTrue);
  });

  testWidgets('renders zeroes for a rider with no returns at all', (
    tester,
  ) async {
    printTestDivider('renders zeroes for a rider with no returns at all');
    // Matches the real payload for a rider with a clean record: every counter
    // zero, breakdown rows present but all zero.
    await pumpCard(
      tester,
      returns(
        total: 0,
        completed: 0,
        pending: 0,
        breakdown: const [
          {'status_id': 5, 'name': 'Out for Pickup', 'count': 0},
          {'status_id': 6, 'name': 'Received from Customer', 'count': 0},
          {'status_id': 7, 'name': 'Return to Store', 'count': 0},
        ],
      ),
    );

    printTestLog(
      'pie chart → expected: 1 (renders on an all-zero breakdown), actual: ${find.byType(ReturnRequestsPieChart).evaluate().length}',
    );
    expect(find.byType(ReturnRequestsPieChart), findsOneWidget);

    final columns = tester
        .widgetList<DashboardStatColumn>(find.byType(DashboardStatColumn))
        .toList();
    printTestLog('completed/pending → expected: "0"/"0", actual: "${columns[0].value}"/"${columns[1].value}"');
    expect(columns[0].value, '0');
    expect(columns[1].value, '0');
  });

  testWidgets('defaults missing counters to zero', (tester) async {
    printTestDivider('defaults missing counters to zero');
    await pumpCard(tester, Returns.fromJson(const <String, dynamic>{}));

    final columns = tester
        .widgetList<DashboardStatColumn>(find.byType(DashboardStatColumn))
        .toList();
    printTestLog('completed → expected: "0", actual: "${columns[0].value}"');
    expect(columns[0].value, '0');
    printTestLog('pending   → expected: "0", actual: "${columns[1].value}"');
    expect(columns[1].value, '0');
  });
}
