import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/features/earnings/screens/earnings_screen.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_quick_access_section.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_skeleton_loader.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_summary_card.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// EarningsScreen builds its own DashboardCubit internally (no own
/// repository/cubit for the feature — it reuses home's DashboardCubit/
/// DashboardModel directly), so a mock DashboardCubit can't be injected the
/// way cash_collection/home's screen tests do. The real cubit and repository
/// run instead, driven through the ApiClient adapter seam — same pattern as
/// `test/features/orders/widgets/order_status_sheet_test.dart`.
void main() {
  late FakeApiAdapter adapter;
  late MockConnectivityCubit connectivityCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late MockLanguageCubit languageCubit;
  late Map<String, dynamic> dashboardResponse;

  setUpAll(() {
    dashboardResponse =
        jsonDecode(
              File('test/fixtures/home/dashboard_response.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  setUp(() async {
    // DioInterceptor reads the auth token out of AuthHiveBox and the
    // language code out of SettingsHiveBox on every request.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.dashboard: (_) => dashboardResponse,
    });
    ApiClient().httpClientAdapter = adapter;

    connectivityCubit = MockConnectivityCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    languageCubit = MockLanguageCubit();

    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityConnected(),
    );
    whenListen(
      languageCubit,
      const Stream<LanguageState>.empty(),
      initialState: LanguageInitial(),
    );
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> waitForResponse(WidgetTester tester) async {
    // The fake adapter's response is fetched in initState; give it a couple
    // of pumps to land (same pattern as order_status_sheet_test.dart).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    ConnectivityState? connectivity,
    Stream<ConnectivityState>? connectivityStream,
    Stream<LanguageState>? languageStream,
    Size viewport = const Size(500, 1400),
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      connectivityCubit,
      connectivityStream ?? const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );
    whenListen(
      languageCubit,
      languageStream ?? const Stream<LanguageState>.empty(),
      initialState: LanguageInitial(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
          BlocProvider<LanguageCubit>.value(value: languageCubit),
        ],
        // EarningsScreen builds its own AppScaffold.
        child: pumpTestWidget(const EarningsScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('fetches the dashboard on first build and shows the skeleton', (
    tester,
  ) async {
    printTestDivider('fetches the dashboard on first build and shows the skeleton');
    await pumpScreen(tester);

    // Checked immediately after the first pump, before the fake adapter's
    // response has a chance to resolve the cubit into DashboardLoaded.
    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(EarningsSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(EarningsSkeletonLoader), findsOneWidget);

    // Let the request travel through the fake adapter, then confirm it was
    // actually made (rather than only asserting the loading UI).
    await waitForResponse(tester);
    printTestLog(
      'dashboard request → expected: contains ${ApiEndpoints.dashboard}, actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, contains(ApiEndpoints.dashboard));
  });

  testWidgets('renders the summary card and quick-access section once loaded', (
    tester,
  ) async {
    printTestDivider('renders the summary card and quick-access section once loaded');
    await pumpScreen(tester);
    await waitForResponse(tester);

    printTestLog(
      'summary card → expected: 1, actual: ${find.byType(EarningsSummaryCard).evaluate().length}',
    );
    expect(find.byType(EarningsSummaryCard), findsOneWidget);
    printTestLog(
      'quick access section → expected: 1, actual: ${find.byType(EarningsQuickAccessSection).evaluate().length}',
    );
    expect(find.byType(EarningsQuickAccessSection), findsOneWidget);
    printTestLog(
      'skeleton → expected: absent, actual: ${find.byType(EarningsSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(EarningsSkeletonLoader), findsNothing);

    // Data threaded through correctly from the fixture's wallet/today blocks.
    final summary = tester.widget<EarningsSummaryCard>(
      find.byType(EarningsSummaryCard),
    );
    printTestLog(
      'totalEarning → expected: 20862.95, actual: ${summary.totalEarning}',
    );
    expect(summary.totalEarning, 20862.95);
    printTestLog('todayEarning → expected: 96.7, actual: ${summary.todayEarning}');
    expect(summary.todayEarning, 96.7);

    final quickAccess = tester.widget<EarningsQuickAccessSection>(
      find.byType(EarningsQuickAccessSection),
    );
    printTestLog(
      'quickAccess.wallet.available → expected: 152.95, actual: ${quickAccess.wallet?.available}',
    );
    expect(quickAccess.wallet?.available, 152.95);
    printTestLog(
      'quickAccess.settlementHistory → expected: 298657.15, actual: ${quickAccess.settlementHistory}',
    );
    expect(quickAccess.settlementHistory, 298657.15);
  });

  testWidgets('shows an error state with retry when the fetch fails', (
    tester,
  ) async {
    printTestDivider('shows an error state with retry when the fetch fails');
    adapter = FakeApiAdapter({
      ApiEndpoints.dashboard: (_) =>
          {'status': 0, 'message': 'Dashboard unavailable'},
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await waitForResponse(tester);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);

    final requestsBefore = adapter.requestedPaths.length;
    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await waitForResponse(tester);

    printTestLog(
      'retry → expected: another dashboard request, requests before: $requestsBefore, after: ${adapter.requestedPaths.length}',
    );
    expect(adapter.requestedPaths.length, greaterThan(requestsBefore));
  });

  testWidgets('shows the offline screen instead of the body when disconnected', (
    tester,
  ) async {
    printTestDivider('shows the offline screen instead of the body when disconnected');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());
    await waitForResponse(tester);

    printTestLog(
      'offline screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog(
      'summary card → expected: absent, actual: ${find.byType(EarningsSummaryCard).evaluate().length}',
    );
    expect(find.byType(EarningsSummaryCard), findsNothing);

    final requestsBefore = adapter.requestedPaths.length;
    final offlineScreen = tester.widget<AppNoInternetFullScreen>(
      find.byType(AppNoInternetFullScreen),
    );
    offlineScreen.onRetry!();
    await tester.pump();
    await waitForResponse(tester);

    printTestLog(
      'offline retry → expected: another dashboard request, before: $requestsBefore, after: ${adapter.requestedPaths.length}',
    );
    expect(adapter.requestedPaths.length, greaterThan(requestsBefore));
  });

  testWidgets('reconnecting refetches the dashboard', (tester) async {
    printTestDivider('reconnecting refetches the dashboard');
    final controller = StreamController<ConnectivityState>();
    addTearDown(controller.close);

    await pumpScreen(
      tester,
      connectivity: ConnectivityConnected(),
      connectivityStream: controller.stream,
    );
    await waitForResponse(tester);
    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;

    controller.add(ConnectivityConnected());
    await tester.pump();
    await waitForResponse(tester);

    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;
    printTestLog('dashboard requests → before: $before, after reconnect: $after');
    expect(after, greaterThan(before));
  });

  testWidgets('a language change (selectedId changing) refetches the dashboard', (
    tester,
  ) async {
    printTestDivider('a language change (selectedId changing) refetches the dashboard');
    final controller = StreamController<LanguageState>();
    addTearDown(controller.close);

    await pumpScreen(tester, languageStream: controller.stream);
    await waitForResponse(tester);
    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;

    controller.add(LanguageLoaded(languages: const [], selectedId: 'en'));
    await tester.pump();
    controller.add(LanguageLoaded(languages: const [], selectedId: 'fr'));
    await tester.pump();
    await waitForResponse(tester);

    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;
    printTestLog(
      'dashboard requests → before: $before, after selectedId change: $after',
    );
    expect(after, greaterThan(before));
  });

  testWidgets('pulling down refetches the dashboard', (tester) async {
    printTestDivider('pulling down refetches the dashboard');
    await pumpScreen(tester);
    await waitForResponse(tester);
    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;

    // RefreshIndicatorState.show() drives the same onRefresh callback a real
    // pull gesture would, without depending on the scroll view actually
    // having overflow content to drag against (a manually-driven drag gesture
    // here was flaky depending on viewport height — see TESTING.md's
    // RefreshIndicator gotcha for the general shape of the problem). It must
    // not be awaited directly: show()'s returned future only completes once
    // its entry animation finishes ticking, which needs pumps to drive — an
    // outright await hangs the test until the 10-minute timeout.
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    // The indicator's own entry animation has to tick before its onRefresh
    // future resolves.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await waitForResponse(tester);

    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;
    printTestLog('dashboard requests → before: $before, after pull-to-refresh: $after');
    expect(after, greaterThan(before));
  });
}
