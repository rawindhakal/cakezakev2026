import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/list_skeleton_loader.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/cash_collection/cubit/cash_collection_cubit.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';
import 'package:deliveryboy/features/cash_collection/screens/cash_collection_screen.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_card.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_summary_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCashCollectionCubit cubit;
  late MockConnectivityCubit connectivityCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late List<CashCollectionModel> entries;

  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    final response =
        jsonDecode(
              File(
                'test/fixtures/cash_collection/cash_collections_list.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    entries = (response['data']['transactions'] as List)
        .map(
          (e) => CashCollectionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    cubit = MockCashCollectionCubit();
    connectivityCubit = MockConnectivityCubit();
    countrySettingsCubit = MockCountrySettingsCubit();

    when(() => cubit.loadCollections()).thenAnswer((_) async {});
    when(() => cubit.loadMore()).thenAnswer((_) async {});
    when(() => cubit.startDate).thenReturn(null);
    when(() => cubit.endDate).thenReturn(null);
    when(() => cubit.hasActiveFilters).thenReturn(false);
    when(() => cubit.cashInHand).thenReturn(null);
    when(() => cubit.cashCollected).thenReturn(null);
    when(
      () => cubit.updateFilters(
        search: any(named: 'search'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});
    when(() => cubit.clearFilters()).thenAnswer((_) async {});
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<CashCollectionModel>? state,
    ConnectivityState? connectivity,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<CashCollectionModel>>.empty(),
      initialState:
          state ?? PaginationLoaded<CashCollectionModel>(data: entries, total: 3),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CashCollectionCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        // CashCollectionScreen builds its own AppScaffold.
        child: pumpTestWidget(const CashCollectionScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads collections on first build', (tester) async {
    printTestDivider('loads collections on first build');
    await pumpScreen(tester);

    verify(() => cubit.loadCollections()).called(1);
    printTestLog('initial load → verified');
  });

  testWidgets('shows the skeleton while loading', (tester) async {
    printTestDivider('shows the skeleton while loading');
    await pumpScreen(
      tester,
      state: const PaginationLoading<CashCollectionModel>(),
    );

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(ListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(ListSkeletonLoader), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(CashCollectionCard).evaluate().length}',
    );
    expect(find.byType(CashCollectionCard), findsNothing);
  });

  testWidgets('shows the loaded list with the summary card', (tester) async {
    printTestDivider('shows the loaded list with the summary card');
    await pumpScreen(tester);

    printTestLog(
      'summary card → expected: 1, actual: ${find.byType(CashCollectionSummaryCard).evaluate().length}',
    );
    expect(find.byType(CashCollectionSummaryCard), findsOneWidget);
    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(CashCollectionCard).evaluate().length}',
    );
    expect(find.byType(CashCollectionCard), findsNWidgets(entries.length));
  });

  testWidgets('shows the error state with a retry when the list fails', (
    tester,
  ) async {
    printTestDivider('shows the error state with a retry when the list fails');
    await pumpScreen(
      tester,
      state: const PaginationError<CashCollectionModel>(
        'Cash collections unavailable',
      ),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Cash collections unavailable" visible');
    expect(find.text('Cash collections unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state refetches the list', (tester) async {
    printTestDivider('retry on the error state refetches the list');
    await pumpScreen(
      tester,
      state: const PaginationError<CashCollectionModel>(
        'Cash collections unavailable',
      ),
    );

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    // Once from initState, once from the retry.
    verify(() => cubit.loadCollections()).called(2);
    printTestLog('refetch → verified');
  });

  testWidgets('replaces the body with the offline screen when disconnected', (
    tester,
  ) async {
    printTestDivider('replaces the body with the offline screen when disconnected');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    printTestLog(
      'offline screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog(
      'summary card → expected: 0, actual: ${find.byType(CashCollectionSummaryCard).evaluate().length}',
    );
    expect(find.byType(CashCollectionSummaryCard), findsNothing);
  });

  testWidgets('reconnecting triggers a reload', (tester) async {
    printTestDivider('reconnecting triggers a reload');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<CashCollectionModel>>.empty(),
      initialState: PaginationLoaded<CashCollectionModel>(data: entries, total: 3),
    );
    final connectivityController = StreamController<ConnectivityState>();
    addTearDown(connectivityController.close);
    whenListen(
      connectivityCubit,
      connectivityController.stream,
      initialState: ConnectivityDisconnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CashCollectionCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(const CashCollectionScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();

    connectivityController.add(ConnectivityConnected());
    await tester.pump();

    // Once from initState, once from the listener firing on reconnect.
    verify(() => cubit.loadCollections()).called(2);
    printTestLog('reload on reconnect → verified');
  });

  testWidgets('typing in search debounces into updateFilters with the current dates', (
    tester,
  ) async {
    printTestDivider(
      'typing in search debounces into updateFilters with the current dates',
    );
    when(() => cubit.startDate).thenReturn('2026-08-01');
    when(() => cubit.endDate).thenReturn('2026-08-17');
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('searchBtn')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'TXN-000301');
    // Debouncer defaults to 500ms.
    await tester.pump(const Duration(milliseconds: 600));

    verify(
      () => cubit.updateFilters(
        search: 'TXN-000301',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      ),
    ).called(1);
    printTestLog('debounced search → verified');
  });

  testWidgets('clear filters resets the search field and calls clearFilters', (
    tester,
  ) async {
    printTestDivider('clear filters resets the search field and calls clearFilters');
    when(() => cubit.hasActiveFilters).thenReturn(true);
    await pumpScreen(tester);

    // Type while searching, then leave search mode (as a user would after
    // seeing results) — the clear-filters button only shows outside search,
    // since the app bar's own cancel button is already an "X" right next to
    // it while searching.
    await tester.tap(find.byKey(const ValueKey('searchBtn')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'TXN');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('searchCancel')));
    await tester.pump();

    await tester.tap(find.byTooltip(LanguageLabelKeys.filters));
    await tester.pump();
    // The sheet's children slide in; a still-animating button is not
    // hit-testable, so wait out the entrance before tapping.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(LanguageLabelKeys.clear));
    await tester.pump();

    verify(() => cubit.clearFilters()).called(1);
    printTestLog('clearFilters → verified');

    // Cancelling search already cleared the controller; reopening search
    // confirms clear-filters didn't leave stale text behind either.
    await tester.tap(find.byKey(const ValueKey('searchBtn')));
    await tester.pump();
    printTestLog(
      'search field → expected: empty, actual: "${tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text}"',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('shows the active-filter badge on the filter icon when a filter is active', (
    tester,
  ) async {
    printTestDivider(
      'shows the active-filter badge on the filter icon when a filter is active',
    );
    when(() => cubit.hasActiveFilters).thenReturn(true);
    await pumpScreen(tester);

    printTestLog(
      'filter icon tooltip → expected: 1, actual: ${find.byTooltip(LanguageLabelKeys.filters).evaluate().length}',
    );
    expect(find.byTooltip(LanguageLabelKeys.filters), findsOneWidget);
  });

  testWidgets('tapping the filter icon opens the filter bottom sheet', (
    tester,
  ) async {
    printTestDivider('tapping the filter icon opens the filter bottom sheet');
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(LanguageLabelKeys.filters));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog(
      'date-range label → expected: visible, actual: ${find.text(LanguageLabelKeys.dateRange).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.dateRange), findsOneWidget);
  });

  testWidgets('tapping Clear in the filter sheet just closes it when no filter is applied', (
    tester,
  ) async {
    printTestDivider(
      'tapping Clear in the filter sheet just closes it when no filter is applied',
    );
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(LanguageLabelKeys.filters));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(LanguageLabelKeys.clear));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog('cubit.clearFilters() → expected: not called');
    verifyNever(() => cubit.clearFilters());
    printTestLog(
      'sheet closed → expected: no date-range label, actual: ${find.text(LanguageLabelKeys.dateRange).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.dateRange), findsNothing);
  });

  testWidgets('tapping Clear in the filter sheet clears filters when one is applied', (
    tester,
  ) async {
    printTestDivider(
      'tapping Clear in the filter sheet clears filters when one is applied',
    );
    when(() => cubit.hasActiveFilters).thenReturn(true);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip(LanguageLabelKeys.filters));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(LanguageLabelKeys.clear));
    await tester.pump();

    printTestLog('cubit.clearFilters() → expected: called once');
    verify(() => cubit.clearFilters()).called(1);
  });
}
