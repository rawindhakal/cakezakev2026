import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_stat_card.dart';
import 'package:deliveryboy/features/home/widgets/earnings_trend_card.dart';
import 'package:deliveryboy/features/home/widgets/home_overview_section.dart';
import 'package:deliveryboy/features/home/widgets/order_status_grid.dart';
import 'package:deliveryboy/features/home/widgets/return_requests_card.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCountrySettingsCubit countrySettingsCubit;

  setUp(() {
    countrySettingsCubit = MockCountrySettingsCubit();
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
    whenListen(
      countrySettingsCubit,
      const Stream<CountrySettingsState>.empty(),
      initialState: CountrySettingsInitial(),
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  DashboardModel dashboard({
    Map<String, dynamic>? orders,
    Map<String, dynamic>? wallet,
    Map<String, dynamic>? cash,
    List<Map<String, dynamic>>? statusBreakdown,
    Map<String, dynamic>? returns,
    Map<String, dynamic>? earningsTrend,
  }) => DashboardModel.fromJson({
    'status': 1,
    'data': {
      'orders':
          orders ??
          const {
            'total': 31,
            'active': 6,
            'delivered': 25,
            'cancelled': 0,
            'quick': 26,
            'ecommerce': 5,
          },
      'wallet': wallet ?? const {'available': 152.95},
      'cash': cash ?? const {'in_hand': 16703.34},
      'status_breakdown': ?statusBreakdown,
      'returns': ?returns,
      'earnings_trend': ?earningsTrend,
    },
  });

  Future<void> pumpSection(WidgetTester tester, DashboardModel model) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      BlocProvider<CountrySettingsCubit>.value(
        value: countrySettingsCubit,
        child: pumpTestWidget(
          SingleChildScrollView(
            child: HomeOverviewSection(
              dashboard: model,
              earningsPeriod: LanguageLabelKeys.last7Days,
              onEarningsPeriodChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The three rate bars (success, cancellation, in-progress) are the only
  /// LinearProgressIndicators in the section.
  List<double?> rateValues(WidgetTester tester) => tester
      .widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )
      .map((w) => w.value)
      .toList();

  testWidgets('shows the four overview tiles with currency-prefixed amounts', (
    tester,
  ) async {
    printTestDivider('shows the four overview tiles with currency-prefixed amounts');
    await pumpSection(tester, dashboard());

    final cards = tester
        .widgetList<DashboardStatCard>(find.byType(DashboardStatCard))
        .toList();
    printTestLog('stat cards → expected: 4, actual: ${cards.length}');
    expect(cards.length, 4);
    printTestLog('active orders → expected: "6", actual: "${cards[0].value}"');
    expect(cards[0].value, '6');
    printTestLog('available balance → expected: "₹152.95", actual: "${cards[1].value}"');
    expect(cards[1].value, '₹152.95');
    // Cash in hand is truncated to whole units at the call site.
    printTestLog('cash in hand → expected: "₹16703", actual: "${cards[2].value}"');
    expect(cards[2].value, '₹16703');
    printTestLog('total orders → expected: "31", actual: "${cards[3].value}"');
    expect(cards[3].value, '31');
  });

  testWidgets('computes the delivery, cancellation and in-progress rates', (
    tester,
  ) async {
    printTestDivider('computes the delivery, cancellation and in-progress rates');
    await pumpSection(
      tester,
      dashboard(
        orders: const {
          'total': 10,
          'active': 2,
          'delivered': 7,
          'cancelled': 1,
        },
      ),
    );

    final values = rateValues(tester);
    printTestLog('rate bars → expected: 3, actual: ${values.length}');
    expect(values.length, 3);
    printTestLog('success rate → expected: 0.7, actual: ${values[0]}');
    expect(values[0], closeTo(0.7, 0.0001));
    printTestLog('cancellation rate → expected: 0.1, actual: ${values[1]}');
    expect(values[1], closeTo(0.1, 0.0001));
    printTestLog('in-progress rate → expected: 0.2, actual: ${values[2]}');
    expect(values[2], closeTo(0.2, 0.0001));

    printTestLog('success percent label → expected: "70%" visible');
    expect(find.text('70%'), findsOneWidget);
    printTestLog('cancellation percent label → expected: "10%" visible');
    expect(find.text('10%'), findsOneWidget);
    printTestLog('in-progress percent label → expected: "20%" visible');
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('reports every rate as zero for a rider with no orders', (
    tester,
  ) async {
    printTestDivider('reports every rate as zero for a rider with no orders');
    // Guards the `total == 0 ? 0 : delivered / total` branch — without it a
    // brand-new rider would divide by zero.
    await pumpSection(
      tester,
      dashboard(
        orders: const {
          'total': 0,
          'active': 0,
          'delivered': 0,
          'cancelled': 0,
        },
      ),
    );

    final values = rateValues(tester);
    printTestLog('rate bars → expected: all 0.0, actual: $values');
    expect(values, everyElement(0.0));
    printTestLog('percent labels → expected: three "0%", actual: ${find.text('0%').evaluate().length}');
    expect(find.text('0%'), findsNWidgets(3));
  });

  testWidgets('defaults every counter to zero when the orders block is missing', (
    tester,
  ) async {
    printTestDivider(
      'defaults every counter to zero when the orders block is missing',
    );
    final model = DashboardModel.fromJson(const {
      'status': 1,
      'data': <String, dynamic>{},
    });
    await pumpSection(tester, model);

    final cards = tester
        .widgetList<DashboardStatCard>(find.byType(DashboardStatCard))
        .toList();
    printTestLog('active orders → expected: "0", actual: "${cards[0].value}"');
    expect(cards[0].value, '0');
    // "₹0.0", not "₹0": the fallback literal in `available ?? 0` sits in a
    // double context, so Dart widens it to 0.0 and it renders with the
    // decimal. The cash tile avoids this only because it calls .toInt().
    printTestLog('available balance → expected: "₹0.0", actual: "${cards[1].value}"');
    expect(cards[1].value, '₹0.0');
    printTestLog('rate bars → expected: all 0.0, actual: ${rateValues(tester)}');
    expect(rateValues(tester), everyElement(0.0));
  });

  testWidgets('hides the return-to-store status from the order breakdown', (
    tester,
  ) async {
    printTestDivider('hides the return-to-store status from the order breakdown');
    // status_id 7 is the return-to-store bucket and belongs to the returns
    // card, not the active-orders chart.
    await pumpSection(
      tester,
      dashboard(
        statusBreakdown: const [
          {'status_id': 5, 'name': 'Out For Delivery', 'count': 5},
          {'status_id': 6, 'name': 'Delivered', 'count': 25},
          {'status_id': 7, 'name': 'Return to Store', 'count': 3},
        ],
      ),
    );

    final grid = tester.widget<OrderStatusGrid>(find.byType(OrderStatusGrid));
    final names = grid.statuses.map((s) => s.name).toList();
    printTestLog('statuses → expected: without "Return to Store", actual: $names');
    expect(names, isNot(contains('Return to Store')));
    expect(names.length, 2);
  });

  testWidgets('passes the order-type counts through to the status grid', (
    tester,
  ) async {
    printTestDivider('passes the order-type counts through to the status grid');
    await pumpSection(tester, dashboard());

    final grid = tester.widget<OrderStatusGrid>(find.byType(OrderStatusGrid));
    printTestLog('quick → expected: 26, actual: ${grid.quick}');
    expect(grid.quick, 26);
    printTestLog('ecommerce → expected: 5, actual: ${grid.ecommerce}');
    expect(grid.ecommerce, 5);
    printTestLog('completed → expected: 25, actual: ${grid.completed}');
    expect(grid.completed, 25);
  });

  testWidgets('omits the returns and trend cards when those blocks are absent', (
    tester,
  ) async {
    printTestDivider(
      'omits the returns and trend cards when those blocks are absent',
    );
    await pumpSection(tester, dashboard());

    printTestLog(
      'returns card → expected: absent, actual: ${find.byType(ReturnRequestsCard).evaluate().length}',
    );
    expect(find.byType(ReturnRequestsCard), findsNothing);
    printTestLog(
      'trend card → expected: absent, actual: ${find.byType(EarningsTrendCard).evaluate().length}',
    );
    expect(find.byType(EarningsTrendCard), findsNothing);
  });

  testWidgets('renders the returns and trend cards when the blocks come back', (
    tester,
  ) async {
    printTestDivider('renders the returns and trend cards when the blocks come back');
    await pumpSection(
      tester,
      dashboard(
        returns: const {'total': 0, 'completed': 0, 'pending': 0},
        earningsTrend: const {
          'labels': ['11 Aug', '17 Aug'],
          'data': [526.25, 96.7],
          'trend': '7',
          'total': 862.95,
        },
      ),
    );

    printTestLog(
      'returns card → expected: 1, actual: ${find.byType(ReturnRequestsCard).evaluate().length}',
    );
    expect(find.byType(ReturnRequestsCard), findsOneWidget);
    printTestLog(
      'trend card → expected: 1, actual: ${find.byType(EarningsTrendCard).evaluate().length}',
    );
    expect(find.byType(EarningsTrendCard), findsOneWidget);

    final trendCard = tester.widget<EarningsTrendCard>(
      find.byType(EarningsTrendCard),
    );
    printTestLog('trend currency → expected: "₹", actual: "${trendCard.currencySymbol}"');
    expect(trendCard.currencySymbol, '₹');
  });

  testWidgets('clamps a rate above 100% into the progress bar track', (
    tester,
  ) async {
    printTestDivider('clamps a rate above 100% into the progress bar track');
    // A backend reporting more delivered than total would otherwise push the
    // indicator past its track.
    await pumpSection(
      tester,
      dashboard(
        orders: const {
          'total': 10,
          'active': 0,
          'delivered': 18,
          'cancelled': 0,
        },
      ),
    );

    final values = rateValues(tester);
    printTestLog('success rate → expected: clamped to 1.0, actual: ${values[0]}');
    expect(values[0], 1.0);
    // The label is not clamped — it still reports the raw figure.
    printTestLog('success label → expected: "180%" visible');
    expect(find.text('180%'), findsOneWidget);
  });
}
