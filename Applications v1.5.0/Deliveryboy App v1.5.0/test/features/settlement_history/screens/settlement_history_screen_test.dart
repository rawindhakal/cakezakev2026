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
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/list_skeleton_loader.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/settlement_history/cubit/settlement_history_cubit.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/features/settlement_history/screens/settlement_history_screen.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_card.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_list.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockSettlementHistoryCubit cubit;
  late MockConnectivityCubit connectivityCubit;
  late List<SettlementHistoryData> entries;

  setUp(() async {
    // The cards format created_at through AppDateFormatter, which reads the
    // server-provided format out of SettingsHiveBox.
    await HiveTestHelper.setUp(settingsBox);
    final response =
        jsonDecode(
              File(
                'test/fixtures/settlement_history/settlement_history_list.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    entries = SettlementHistoryResponse.fromJson(response).data!;

    cubit = MockSettlementHistoryCubit();
    connectivityCubit = MockConnectivityCubit();

    when(() => cubit.loadTransfers()).thenAnswer((_) async {});
    when(() => cubit.loadMore()).thenAnswer((_) async {});
    when(() => cubit.search).thenReturn('');
    when(() => cubit.entryType).thenReturn('');
    when(() => cubit.startDate).thenReturn(null);
    when(() => cubit.endDate).thenReturn(null);
    when(() => cubit.hasActiveFilters).thenReturn(false);
    when(
      () => cubit.updateFilters(
        search: any(named: 'search'),
        entryType: any(named: 'entryType'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});
    when(() => cubit.clearFilters()).thenAnswer((_) async {});
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Widget buildScreen() => MultiBlocProvider(
    providers: [
      BlocProvider<SettlementHistoryCubit>.value(value: cubit),
      BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
    ],
    // SettlementHistoryScreen builds its own AppScaffold.
    child: pumpTestWidget(
      const SettlementHistoryScreen(),
      wrapInScaffold: false,
    ),
  );

  void sizeViewport(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
  }

  // Unlike the cash_collection and orders screens, this screen's filter
  // IconButton carries no `tooltip`, so it can't be found by one — locate it
  // through the SVG asset it renders instead.
  final filterIcon = find.byWidgetPredicate(
    (w) => w is AppSvgIcon && w.path == AssetsConstants.filterIcon,
  );
  final filterButton = find.ancestor(
    of: filterIcon,
    matching: find.byType(IconButton),
  );
  // The active-filter dot is the Positioned sibling of the IconButton inside
  // the badge Stack.
  final filterBadge = find.descendant(
    of: find.ancestor(of: filterIcon, matching: find.byType(Stack)).first,
    matching: find.byType(Positioned),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<SettlementHistoryData>? state,
    ConnectivityState? connectivity,
  }) async {
    sizeViewport(tester);

    whenListen(
      cubit,
      const Stream<PaginationState<SettlementHistoryData>>.empty(),
      initialState:
          state ??
          PaginationLoaded<SettlementHistoryData>(data: entries, total: 3),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();
  }

  testWidgets('loads the first page of transfers on first build', (
    tester,
  ) async {
    printTestDivider('loads the first page of transfers on first build');
    await pumpScreen(tester);

    verify(() => cubit.loadTransfers()).called(1);
    printTestLog('initial load → verified');
  });

  testWidgets('shows the screen title in the app bar', (tester) async {
    printTestDivider('shows the screen title in the app bar');
    await pumpScreen(tester);

    printTestLog(
      'title → expected: "${LanguageLabelKeys.settlementHistory}" visible',
    );
    expect(find.text(LanguageLabelKeys.settlementHistory), findsOneWidget);
  });

  testWidgets('shows the skeleton while loading', (tester) async {
    printTestDivider('shows the skeleton while loading');
    await pumpScreen(
      tester,
      state: const PaginationLoading<SettlementHistoryData>(),
    );

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(ListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(ListSkeletonLoader), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(SettlementHistoryCard).evaluate().length}',
    );
    expect(find.byType(SettlementHistoryCard), findsNothing);
  });

  testWidgets('shows the loaded list with one card per entry', (tester) async {
    printTestDivider('shows the loaded list with one card per entry');
    await pumpScreen(tester);

    printTestLog(
      'list → expected: 1, actual: ${find.byType(TransferList).evaluate().length}',
    );
    expect(find.byType(TransferList), findsOneWidget);
    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(SettlementHistoryCard).evaluate().length}',
    );
    expect(
      find.byType(SettlementHistoryCard),
      findsNWidgets(entries.length),
    );
  });

  testWidgets('renders nothing but the app bar in the initial state', (
    tester,
  ) async {
    printTestDivider('renders nothing but the app bar in the initial state');
    await pumpScreen(
      tester,
      state: const PaginationInitial<SettlementHistoryData>(),
    );

    printTestLog(
      'list → expected: 0, actual: ${find.byType(TransferList).evaluate().length}',
    );
    expect(find.byType(TransferList), findsNothing);
    printTestLog(
      'skeleton → expected: 0, actual: ${find.byType(ListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(ListSkeletonLoader), findsNothing);
    printTestLog('title → expected: still visible');
    expect(find.text(LanguageLabelKeys.settlementHistory), findsOneWidget);
  });

  testWidgets('shows the error state with the API message when the list fails', (
    tester,
  ) async {
    printTestDivider('shows the error state with the API message when the list fails');
    await pumpScreen(
      tester,
      state: const PaginationError<SettlementHistoryData>(
        'Settlement history unavailable',
      ),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Settlement history unavailable" visible');
    expect(find.text('Settlement history unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state refetches the list', (tester) async {
    printTestDivider('retry on the error state refetches the list');
    await pumpScreen(
      tester,
      state: const PaginationError<SettlementHistoryData>(
        'Settlement history unavailable',
      ),
    );

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    // Once from initState, once from the retry.
    verify(() => cubit.loadTransfers()).called(2);
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
      'list → expected: 0, actual: ${find.byType(TransferList).evaluate().length}',
    );
    expect(find.byType(TransferList), findsNothing);
    // The app bar stays so the pushed route keeps its back button.
    printTestLog('title → expected: still visible while offline');
    expect(find.text(LanguageLabelKeys.settlementHistory), findsOneWidget);
  });

  testWidgets('retry on the offline screen refetches the list', (tester) async {
    printTestDivider('retry on the offline screen refetches the list');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    final offline = tester.widget<AppNoInternetFullScreen>(
      find.byType(AppNoInternetFullScreen),
    );
    offline.onRetry!();
    await tester.pump();

    verify(() => cubit.loadTransfers()).called(2);
    printTestLog('refetch → verified');
  });

  testWidgets('reconnecting triggers a reload', (tester) async {
    printTestDivider('reconnecting triggers a reload');
    sizeViewport(tester);

    whenListen(
      cubit,
      const Stream<PaginationState<SettlementHistoryData>>.empty(),
      initialState: PaginationLoaded<SettlementHistoryData>(
        data: entries,
        total: 3,
      ),
    );
    final connectivityController = StreamController<ConnectivityState>();
    addTearDown(connectivityController.close);
    whenListen(
      connectivityCubit,
      connectivityController.stream,
      initialState: ConnectivityDisconnected(),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    connectivityController.add(ConnectivityConnected());
    await tester.pump();

    // Once from initState, once from the listener firing on reconnect.
    verify(() => cubit.loadTransfers()).called(2);
    printTestLog('reload on reconnect → verified');
  });

  group('search', () {
    testWidgets('typing debounces into updateFilters, re-passing the current dates', (
      tester,
    ) async {
      printTestDivider(
        'typing debounces into updateFilters, re-passing the current dates',
      );
      // updateFilters clears any date it isn't handed, so the screen has to
      // read them back off the cubit and pass them through on every search.
      when(() => cubit.startDate).thenReturn('2026-08-01');
      when(() => cubit.endDate).thenReturn('2026-08-17');
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '901');
      // Debouncer defaults to 500ms.
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => cubit.updateFilters(
          search: '901',
          startDate: '2026-08-01',
          endDate: '2026-08-17',
        ),
      ).called(1);
      printTestLog('debounced search → verified');
    });

    testWidgets('trims the typed query before sending it', (tester) async {
      printTestDivider('trims the typed query before sending it');
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '  901  ');
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => cubit.updateFilters(
          search: '901',
          startDate: null,
          endDate: null,
        ),
      ).called(1);
      printTestLog('trimmed search → verified');
    });

    testWidgets('rapid typing only sends the final query once', (tester) async {
      printTestDivider('rapid typing only sends the final query once');
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '9');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextFormField), '90');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextFormField), '901');
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => cubit.updateFilters(
          search: '901',
          startDate: null,
          endDate: null,
        ),
      ).called(1);
      verifyNever(
        () => cubit.updateFilters(
          search: '9',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
      printTestLog('only the final query sent → verified');
    });

    testWidgets('cancelling search with text in the box resets the query', (
      tester,
    ) async {
      printTestDivider('cancelling search with text in the box resets the query');
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '901');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('searchCancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => cubit.updateFilters(
          search: '',
          startDate: null,
          endDate: null,
        ),
      ).called(1);
      printTestLog('reset query on cancel → verified');
    });

    testWidgets('cancelling search with an empty box sends nothing', (
      tester,
    ) async {
      printTestDivider('cancelling search with an empty box sends nothing');
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('searchCancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      verifyNever(
        () => cubit.updateFilters(
          search: any(named: 'search'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
      printTestLog('no refetch on an empty cancel → verified');
    });

    testWidgets('the filter icon is hidden while searching', (tester) async {
      printTestDivider('the filter icon is hidden while searching');
      await pumpScreen(tester);

      printTestLog(
        'filter icon before → expected: 1, actual: ${filterButton.evaluate().length}',
      );
      expect(filterButton, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();

      printTestLog(
        'filter icon while searching → expected: 0, actual: ${filterButton.evaluate().length}',
      );
      expect(filterButton, findsNothing);
    });
  });

  group('filters', () {
    testWidgets('tapping the filter icon opens the filter bottom sheet', (
      tester,
    ) async {
      printTestDivider('tapping the filter icon opens the filter bottom sheet');
      await pumpScreen(tester);

      await tester.tap(filterButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      printTestLog(
        'date-range label → expected: visible, actual: ${find.text(LanguageLabelKeys.dateRange).evaluate().length}',
      );
      expect(find.text(LanguageLabelKeys.dateRange), findsOneWidget);
      printTestLog(
        'type label → expected: visible, actual: ${find.text(LanguageLabelKeys.filterByType).evaluate().length}',
      );
      expect(find.text(LanguageLabelKeys.filterByType), findsOneWidget);
    });

    testWidgets('shows the active-filter badge only when a filter is applied', (
      tester,
    ) async {
      printTestDivider('shows the active-filter badge only when a filter is applied');
      await pumpScreen(tester);

      final withoutFilters = filterBadge.evaluate().length;
      printTestLog('badge without filters → expected: 0, actual: $withoutFilters');
      expect(withoutFilters, 0);
    });

    testWidgets('the badge appears once the cubit reports an active filter', (
      tester,
    ) async {
      printTestDivider('the badge appears once the cubit reports an active filter');
      when(() => cubit.hasActiveFilters).thenReturn(true);
      await pumpScreen(tester);

      final withFilters = filterBadge.evaluate().length;
      printTestLog('badge with filters → expected: 1, actual: $withFilters');
      expect(withFilters, 1);
    });

    testWidgets('clearing filters from the sheet also empties the search box', (
      tester,
    ) async {
      printTestDivider('clearing filters from the sheet also empties the search box');
      when(() => cubit.hasActiveFilters).thenReturn(true);
      await pumpScreen(tester);

      // Type while searching, then leave search mode (as a user would after
      // seeing results) — the filter icon only shows outside search.
      await tester.tap(find.byKey(const ValueKey('searchBtn')));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '901');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('searchCancel')));
      await tester.pump();

      await tester.tap(filterButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(LanguageLabelKeys.clear));
      await tester.pump();

      verify(() => cubit.clearFilters()).called(1);
      printTestLog('clearFilters → verified');

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

    testWidgets('applying a type filter from the sheet forwards it to the cubit', (
      tester,
    ) async {
      printTestDivider('applying a type filter from the sheet forwards it to the cubit');
      await pumpScreen(tester);

      await tester.tap(filterButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(LanguageLabelKeys.withdrawal));
      await tester.pump();
      await tester.tap(find.text(LanguageLabelKeys.apply));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => cubit.updateFilters(
          entryType: 'withdrawal',
          startDate: null,
          endDate: null,
        ),
      ).called(1);
      printTestLog('updateFilters(entryType: "withdrawal") → verified');
    });
  });
}
