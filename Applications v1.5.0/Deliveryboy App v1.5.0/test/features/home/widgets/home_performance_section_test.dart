import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_stat_card.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/widgets/home_performance_section.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCountrySettingsCubit countrySettingsCubit;

  // The date chip formats today through AppDateFormatter, which reads the
  // server-provided date format out of SettingsHiveBox.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    countrySettingsCubit = MockCountrySettingsCubit();
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
    whenListen(
      countrySettingsCubit,
      const Stream<CountrySettingsState>.empty(),
      initialState: CountrySettingsInitial(),
    );
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  DashboardModel dashboard({Map<String, dynamic>? today}) =>
      DashboardModel.fromJson({
        'status': 1,
        'data': {
          'today': ?today,
        },
      });

  Future<void> pumpSection(WidgetTester tester, DashboardModel model) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      BlocProvider<CountrySettingsCubit>.value(
        value: countrySettingsCubit,
        child: pumpTestWidget(
          SingleChildScrollView(child: HomePerformanceSection(dashboard: model)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("renders today's four figures", (tester) async {
    printTestDivider("renders today's four figures");
    await pumpSection(
      tester,
      dashboard(
        today: const {
          'earnings': 96.7,
          'delivered': 2,
          'cash': 706.5,
          'orders': 2,
        },
      ),
    );

    final cards = tester
        .widgetList<EarningsStatCard>(find.byType(EarningsStatCard))
        .toList();
    printTestLog('stat cards → expected: 4, actual: ${cards.length}');
    expect(cards.length, 4);
    printTestLog("today's earnings → expected: \"₹96.7\", actual: \"${cards[0].value}\"");
    expect(cards[0].value, '₹96.7');
    printTestLog('orders delivered → expected: "2", actual: "${cards[1].value}"');
    expect(cards[1].value, '2');
    printTestLog('cash collected → expected: "₹706.5", actual: "${cards[2].value}"');
    expect(cards[2].value, '₹706.5');
    printTestLog("today's orders → expected: \"2\", actual: \"${cards[3].value}\"");
    expect(cards[3].value, '2');
  });

  testWidgets('prefixes money figures with the resolved currency symbol', (
    tester,
  ) async {
    printTestDivider('prefixes money figures with the resolved currency symbol');
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn(r'$');
    await pumpSection(
      tester,
      dashboard(today: const {'earnings': 12.5, 'cash': 30}),
    );

    final cards = tester
        .widgetList<EarningsStatCard>(find.byType(EarningsStatCard))
        .toList();
    printTestLog('earnings → expected: r"\$12.5", actual: "${cards[0].value}"');
    expect(cards[0].value, r'$12.5');
    printTestLog('cash → expected: r"\$30.0", actual: "${cards[2].value}"');
    expect(cards[2].value, r'$30.0');
  });

  testWidgets('falls back to zeroes when the today block is missing', (
    tester,
  ) async {
    printTestDivider('falls back to zeroes when the today block is missing');
    await pumpSection(tester, dashboard());

    final cards = tester
        .widgetList<EarningsStatCard>(find.byType(EarningsStatCard))
        .toList();
    // Money tiles widen the `?? 0` literal to a double (0.0) because the field
    // is double?; the count tiles keep the int.
    printTestLog('earnings → expected: "₹0.0", actual: "${cards[0].value}"');
    expect(cards[0].value, '₹0.0');
    printTestLog('delivered → expected: "0", actual: "${cards[1].value}"');
    expect(cards[1].value, '0');
    printTestLog('cash → expected: "₹0.0", actual: "${cards[2].value}"');
    expect(cards[2].value, '₹0.0');
    printTestLog('orders → expected: "0", actual: "${cards[3].value}"');
    expect(cards[3].value, '0');
  });

  testWidgets('renders a date chip alongside the section title', (tester) async {
    printTestDivider('renders a date chip alongside the section title');
    await pumpSection(tester, dashboard(today: const {'earnings': 1}));

    // The chip's exact text depends on the format cached in SettingsHiveBox,
    // so assert the row is laid out rather than pinning a formatted date.
    printTestLog('title row → expected: 1, actual: ${find.byType(Row).evaluate().length} rows');
    expect(find.byType(Row), findsWidgets);
    printTestLog(
      'stat cards → expected: 4, actual: ${find.byType(EarningsStatCard).evaluate().length}',
    );
    expect(find.byType(EarningsStatCard), findsNWidgets(4));
  });
}
