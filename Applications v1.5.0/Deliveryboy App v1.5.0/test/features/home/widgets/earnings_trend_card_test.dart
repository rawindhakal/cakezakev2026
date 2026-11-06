import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/widgets/earnings_line_chart.dart';
import 'package:deliveryboy/features/home/widgets/earnings_trend_card.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  EarningsTrend trend({
    List<String> labels = const ['11 Aug', '17 Aug'],
    List<double> data = const [526.25, 96.7],
    String trendDirection = 'up',
    double total = 862.95,
  }) => EarningsTrend.fromJson({
    'labels': labels,
    'data': data,
    'trend': trendDirection,
    'total': total,
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    EarningsTrend? earningsTrend,
    String selectedPeriod = LanguageLabelKeys.last7Days,
    ValueChanged<String>? onPeriodChanged,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(
          child: EarningsTrendCard(
            trend: earningsTrend ?? trend(),
            currencySymbol: '₹',
            selectedPeriod: selectedPeriod,
            onPeriodChanged: onPeriodChanged ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('trendValueForPeriod', () {
    test('maps each period label to the API trend value', () {
      printTestDivider('maps each period label to the API trend value');
      final cases = {
        LanguageLabelKeys.last7Days: '7',
        LanguageLabelKeys.last30Days: '30',
        LanguageLabelKeys.last90Days: '90',
        LanguageLabelKeys.last12Months: '12m',
      };
      for (final entry in cases.entries) {
        final actual = trendValueForPeriod(entry.key);
        printTestLog('${entry.key} → expected: "${entry.value}", actual: "$actual"');
        expect(actual, entry.value);
      }
    });

    test('falls back to 7 for an unknown period key', () {
      printTestDivider('falls back to 7 for an unknown period key');
      final actual = trendValueForPeriod('something_else');
      printTestLog('unknown → expected: "7", actual: "$actual"');
      expect(actual, '7');
    });
  });

  group('EarningsTrendCard', () {
    testWidgets('shows the total with its currency symbol', (tester) async {
      printTestDivider('shows the total with its currency symbol');
      await pumpCard(tester);

      printTestLog('total → expected: "₹862.95" visible');
      expect(find.text('₹862.95'), findsOneWidget);
    });

    testWidgets('shows the selected period on the filter button', (
      tester,
    ) async {
      printTestDivider('shows the selected period on the filter button');
      await pumpCard(tester, selectedPeriod: LanguageLabelKeys.last90Days);

      // Translations aren't loaded in tests, so the period falls back to its
      // raw key.
      printTestLog('period → expected: "${LanguageLabelKeys.last90Days}" visible');
      expect(find.text(LanguageLabelKeys.last90Days), findsOneWidget);
    });

    testWidgets('renders the line chart when there are data points', (
      tester,
    ) async {
      printTestDivider('renders the line chart when there are data points');
      await pumpCard(tester);

      printTestLog(
        'chart → expected: 1, actual: ${find.byType(EarningsLineChart).evaluate().length}',
      );
      expect(find.byType(EarningsLineChart), findsOneWidget);
    });

    testWidgets('shows a dash instead of the chart when there is no data', (
      tester,
    ) async {
      printTestDivider('shows a dash instead of the chart when there is no data');
      await pumpCard(tester, earningsTrend: trend(data: const [], labels: const []));

      printTestLog(
        'chart → expected: absent, actual: ${find.byType(EarningsLineChart).evaluate().length}',
      );
      expect(find.byType(EarningsLineChart), findsNothing);
      printTestLog('placeholder → expected: "-" visible');
      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('labels the first and last points of the window', (
      tester,
    ) async {
      printTestDivider('labels the first and last points of the window');
      await pumpCard(
        tester,
        earningsTrend: trend(labels: const ['11 Aug', '14 Aug', '17 Aug']),
      );

      // Only the ends are labelled — the middle labels are dropped.
      printTestLog('first label → expected: "11 Aug" visible');
      expect(find.text('11 Aug'), findsOneWidget);
      printTestLog('last label  → expected: "17 Aug" visible');
      expect(find.text('17 Aug'), findsOneWidget);
      printTestLog('middle label → expected: absent');
      expect(find.text('14 Aug'), findsNothing);
    });

    testWidgets('omits the label row when no labels come back', (tester) async {
      printTestDivider('omits the label row when no labels come back');
      await pumpCard(tester, earningsTrend: trend(labels: const []));

      printTestLog('label → expected: absent, actual: ${find.text('11 Aug').evaluate().length}');
      expect(find.text('11 Aug'), findsNothing);
    });

    testWidgets('picking a period from the menu reports it back', (
      tester,
    ) async {
      printTestDivider('picking a period from the menu reports it back');
      String? picked;
      await pumpCard(tester, onPeriodChanged: (p) => picked = p);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The menu repeats the currently-selected label, so target the entry
      // inside the opened menu rather than the button's own text.
      await tester.tap(find.text(LanguageLabelKeys.last30Days).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      printTestLog(
        'onPeriodChanged → expected: "${LanguageLabelKeys.last30Days}", actual: "$picked"',
      );
      expect(picked, LanguageLabelKeys.last30Days);
    });
  });
}
