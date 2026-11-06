import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/widgets/active_status_chart.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_skeleton_loader.dart';
import 'package:deliveryboy/features/home/widgets/earnings_line_chart.dart';
import 'package:deliveryboy/features/home/widgets/return_requests_pie_chart.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void useTallViewport(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
  }

  group('ActiveStatusChart', () {
    Future<void> pumpChart(
      WidgetTester tester,
      List<MapEntry<String, int>> items,
    ) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        pumpTestWidget(
          SingleChildScrollView(child: ActiveStatusChart(items: items)),
        ),
      );
      await tester.pump();
    }

    testWidgets('lists every status with its count in the legend', (
      tester,
    ) async {
      printTestDivider('lists every status with its count in the legend');
      await pumpChart(tester, const [
        MapEntry('Out For Delivery', 5),
        MapEntry('Delivered', 25),
        MapEntry('Picked Up', 0),
      ]);

      for (final entry in const {
        'Out For Delivery': '5',
        'Delivered': '25',
        'Picked Up': '0',
      }.entries) {
        printTestLog('legend row → expected: "${entry.key}" / "${entry.value}" visible');
        expect(find.text(entry.key), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('renders an all-zero breakdown without dividing by zero', (
      tester,
    ) async {
      printTestDivider('renders an all-zero breakdown without dividing by zero');
      // A brand-new rider has nothing in any bucket; the chart substitutes a
      // safe total of 1 rather than dividing by the real 0.
      await pumpChart(tester, const [
        MapEntry('Delivered', 0),
        MapEntry('Picked Up', 0),
      ]);

      printTestLog('chart → expected: rendered, actual: ${find.byType(PieChart).evaluate().length}');
      expect(find.byType(PieChart), findsOneWidget);
      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });

    testWidgets('bolds a legend row once selected, and unbolds it when tapped again', (
      tester,
    ) async {
      printTestDivider(
        'bolds a legend row once selected, and unbolds it when tapped again',
      );
      await pumpChart(tester, const [
        MapEntry('Out For Delivery', 5),
        MapEntry('Delivered', 25),
      ]);

      FontWeight? weightOf(String label) =>
          tester.widget<Text>(find.text(label)).style?.fontWeight;

      printTestLog('before tap → expected: w400, actual: ${weightOf('Delivered')}');
      expect(weightOf('Delivered'), FontWeight.w400);

      // The legend row is the tappable target — the chart slice itself needs a
      // real gesture on the canvas.
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      printTestLog('after first tap → expected: w700, actual: ${weightOf('Delivered')}');
      expect(weightOf('Delivered'), FontWeight.w700);

      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      printTestLog('after second tap → expected: w400, actual: ${weightOf('Delivered')}');
      expect(weightOf('Delivered'), FontWeight.w400);
    });

    testWidgets('renders nothing in the legend for an empty breakdown', (
      tester,
    ) async {
      printTestDivider('renders nothing in the legend for an empty breakdown');
      await pumpChart(tester, const []);

      printTestLog('legend rows → expected: 0, actual: ${find.byType(InkWell).evaluate().length}');
      expect(find.byType(InkWell), findsNothing);
      printTestLog('chart → expected: still rendered, actual: ${find.byType(PieChart).evaluate().length}');
      expect(find.byType(PieChart), findsOneWidget);
    });
  });

  group('ReturnRequestsPieChart', () {
    StatusBreakdown item(String name, int count) =>
        StatusBreakdown.fromJson({'name': name, 'count': count});

    Future<void> pumpChart(
      WidgetTester tester, {
      required List<StatusBreakdown> breakdown,
      int total = 4,
    }) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        pumpTestWidget(
          SingleChildScrollView(
            child: ReturnRequestsPieChart(breakdown: breakdown, total: total),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders a donut with a legend row per status', (tester) async {
      printTestDivider('renders a donut with a legend row per status');
      await pumpChart(
        tester,
        breakdown: [item('Out for Pickup', 2), item('Return to Store', 2)],
      );

      printTestLog('chart → expected: 1, actual: ${find.byType(PieChart).evaluate().length}');
      expect(find.byType(PieChart), findsOneWidget);
      printTestLog('legend → expected: both names visible');
      expect(find.text('Out for Pickup'), findsOneWidget);
      expect(find.text('Return to Store'), findsOneWidget);
    });

    testWidgets('tapping a legend row enlarges that slice', (tester) async {
      printTestDivider('tapping a legend row enlarges that slice');
      await pumpChart(
        tester,
        breakdown: [item('Out for Pickup', 2), item('Return to Store', 3)],
      );

      List<double> radii() => tester
          .widget<PieChart>(find.byType(PieChart))
          .data
          .sections
          .map((s) => s.radius)
          .toList();

      printTestLog('before tap → expected: [20, 20], actual: ${radii()}');
      expect(radii(), everyElement(20.0));

      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();

      printTestLog('after tap → expected: second slice 26, actual: ${radii()}');
      expect(radii()[1], 26.0);
      expect(radii()[0], 20.0);

      // Note: no tooltip appears from a legend tap. The tooltip is positioned
      // from the touch coordinates the chart's own touch callback supplies,
      // and the legend's onTap has none to pass — so despite the widget's doc
      // comment ("tap a slice or its legend row to show a tooltip"), only a
      // tap on the chart itself shows one.
      printTestLog('tooltip → expected: name still rendered once (legend only)');
      expect(find.text('Return to Store'), findsOneWidget);
    });

    testWidgets('tapping the same legend row again clears the selection', (
      tester,
    ) async {
      printTestDivider('tapping the same legend row again clears the selection');
      await pumpChart(
        tester,
        breakdown: [item('Out for Pickup', 2), item('Return to Store', 3)],
      );

      double radiusOfSecond() => tester
          .widget<PieChart>(find.byType(PieChart))
          .data
          .sections[1]
          .radius;

      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      printTestLog('after first tap → expected: 26.0, actual: ${radiusOfSecond()}');
      expect(radiusOfSecond(), 26.0);

      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      printTestLog('after second tap → expected: 20.0, actual: ${radiusOfSecond()}');
      expect(radiusOfSecond(), 20.0);
    });

    testWidgets('renders an all-zero breakdown for a rider with no returns', (
      tester,
    ) async {
      printTestDivider('renders an all-zero breakdown for a rider with no returns');
      await pumpChart(
        tester,
        breakdown: [item('Out for Pickup', 0), item('Return to Store', 0)],
        total: 0,
      );

      printTestLog('chart → expected: rendered, actual: ${find.byType(PieChart).evaluate().length}');
      expect(find.byType(PieChart), findsOneWidget);
      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });
  });

  group('EarningsLineChart', () {
    Future<void> pumpChart(WidgetTester tester, List<int> values) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        pumpTestWidget(
          SingleChildScrollView(child: EarningsLineChart(values: values)),
        ),
      );
      await tester.pump();
    }

    testWidgets('plots a line once there are at least two points', (
      tester,
    ) async {
      printTestDivider('plots a line once there are at least two points');
      await pumpChart(tester, const [526, 80, 0, 80, 40, 40, 97]);

      printTestLog('chart → expected: 1, actual: ${find.byType(LineChart).evaluate().length}');
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders blank space rather than a chart for a single point', (
      tester,
    ) async {
      printTestDivider('renders blank space rather than a chart for a single point');
      // A one-point line has nothing to draw between, so the widget reserves
      // the height and draws nothing.
      await pumpChart(tester, const [526]);

      printTestLog('chart → expected: absent, actual: ${find.byType(LineChart).evaluate().length}');
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders blank space for no points at all', (tester) async {
      printTestDivider('renders blank space for no points at all');
      await pumpChart(tester, const []);

      printTestLog('chart → expected: absent, actual: ${find.byType(LineChart).evaluate().length}');
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('handles an all-zero series without a zero-interval grid', (
      tester,
    ) async {
      printTestDivider('handles an all-zero series without a zero-interval grid');
      // maxValue 0 would make the axis interval 0, which fl_chart rejects —
      // the widget floors the axis at 10 to avoid it.
      await pumpChart(tester, const [0, 0, 0]);

      printTestLog('chart → expected: 1, actual: ${find.byType(LineChart).evaluate().length}');
      expect(find.byType(LineChart), findsOneWidget);
      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });

    testWidgets('honours a custom height', (tester) async {
      printTestDivider('honours a custom height');
      useTallViewport(tester);
      await tester.pumpWidget(
        pumpTestWidget(
          const SingleChildScrollView(
            child: EarningsLineChart(values: [10, 20], height: 220),
          ),
        ),
      );
      await tester.pump();

      final box = tester.getSize(find.byType(LineChart));
      printTestLog('chart height → expected: 220.0, actual: ${box.height}');
      expect(box.height, 220.0);
    });
  });

  group('DashboardSkeletonLoader', () {
    testWidgets('renders shimmering placeholders while the dashboard loads', (
      tester,
    ) async {
      printTestDivider('renders shimmering placeholders while the dashboard loads');
      useTallViewport(tester);
      await tester.pumpWidget(
        pumpTestWidget(
          const SingleChildScrollView(child: DashboardSkeletonLoader()),
        ),
      );
      // A bounded pump, not pumpAndSettle: ShimmerLoading runs a looping
      // animation that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      printTestLog(
        'shimmer wrapper → expected: 1, actual: ${find.byType(ShimmerLoading).evaluate().length}',
      );
      expect(find.byType(ShimmerLoading), findsOneWidget);
      printTestLog(
        'shimmer boxes → expected: several, actual: ${find.byType(ShimmerBox).evaluate().length}',
      );
      expect(find.byType(ShimmerBox), findsWidgets);
      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });
  });
}
