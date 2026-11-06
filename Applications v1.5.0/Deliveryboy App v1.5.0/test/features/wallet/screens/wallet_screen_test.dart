import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/list_skeleton_loader.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';
import 'package:deliveryboy/features/wallet/screens/wallet_screen.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_balance_card.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_transaction_item.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockWalletCubit cubit;
  late MockConnectivityCubit connectivityCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late List<WithdrawRequests> entries;

  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    entries = List.generate(
      3,
      (i) => WithdrawRequests.fromJson({
        'id': '${i + 1}',
        'amount': '${(i + 1) * 100}.00',
        'status': '0',
        'currency': '₹',
      }),
    );

    cubit = MockWalletCubit();
    connectivityCubit = MockConnectivityCubit();
    countrySettingsCubit = MockCountrySettingsCubit();

    when(() => cubit.loadWallet()).thenAnswer((_) {});
    when(() => cubit.loadMore()).thenAnswer((_) async {});
    when(() => cubit.balance).thenReturn(4520.75);
    when(() => cubit.search(any())).thenAnswer((_) async {});
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<WithdrawRequests>? state,
    ConnectivityState? connectivity,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<WithdrawRequests>>.empty(),
      initialState:
          state ?? WalletLoaded(data: entries, total: 3, hasMore: false),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        // WalletScreen builds its own AppScaffold.
        child: pumpTestWidget(const WalletScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads wallet data on first build', (tester) async {
    printTestDivider('loads wallet data on first build');
    await pumpScreen(tester);

    verify(() => cubit.loadWallet()).called(1);
    printTestLog('initial load → verified');
  });

  testWidgets('shows the skeleton while loading', (tester) async {
    printTestDivider('shows the skeleton while loading');
    await pumpScreen(
      tester,
      state: const PaginationLoading<WithdrawRequests>(),
    );

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(ListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(ListSkeletonLoader), findsOneWidget);
    printTestLog(
      'items → expected: 0, actual: ${find.byType(WalletTransactionItem).evaluate().length}',
    );
    expect(find.byType(WalletTransactionItem), findsNothing);
  });

  testWidgets('shows the loaded list with the balance card', (tester) async {
    printTestDivider('shows the loaded list with the balance card');
    await pumpScreen(tester);

    printTestLog(
      'balance card → expected: 1, actual: ${find.byType(WalletBalanceCard).evaluate().length}',
    );
    expect(find.byType(WalletBalanceCard), findsOneWidget);
    printTestLog(
      'items → expected: ${entries.length}, actual: ${find.byType(WalletTransactionItem).evaluate().length}',
    );
    expect(find.byType(WalletTransactionItem), findsNWidgets(entries.length));
  });

  testWidgets('shows the error state with a retry when the list fails', (
    tester,
  ) async {
    printTestDivider('shows the error state with a retry when the list fails');
    await pumpScreen(
      tester,
      state: const PaginationError<WithdrawRequests>('Wallet unavailable'),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Wallet unavailable" visible');
    expect(find.text('Wallet unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state refetches the wallet', (tester) async {
    printTestDivider('retry on the error state refetches the wallet');
    await pumpScreen(
      tester,
      state: const PaginationError<WithdrawRequests>('Wallet unavailable'),
    );

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    // Once from initState, once from the retry.
    verify(() => cubit.loadWallet()).called(2);
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
      'balance card → expected: 0, actual: ${find.byType(WalletBalanceCard).evaluate().length}',
    );
    expect(find.byType(WalletBalanceCard), findsNothing);
  });

  testWidgets('reconnecting triggers a reload', (tester) async {
    printTestDivider('reconnecting triggers a reload');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<WithdrawRequests>>.empty(),
      initialState: WalletLoaded(data: entries, total: 3, hasMore: false),
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
          BlocProvider<WalletCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(const WalletScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();

    connectivityController.add(ConnectivityConnected());
    await tester.pump();

    // Once from initState, once from the listener firing on reconnect.
    verify(() => cubit.loadWallet()).called(2);
    printTestLog('reload on reconnect → verified');
  });

  testWidgets('typing in search debounces into WalletCubit.search', (
    tester,
  ) async {
    printTestDivider('typing in search debounces into WalletCubit.search');
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('searchBtn')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'John');
    // Debouncer defaults to 500ms.
    await tester.pump(const Duration(milliseconds: 600));

    verify(() => cubit.search('John')).called(1);
    printTestLog('debounced search → verified');
  });

  testWidgets('tapping the filter icon opens the filter bottom sheet', (
    tester,
  ) async {
    printTestDivider('tapping the filter icon opens the filter bottom sheet');
    when(() => cubit.selectedStatus).thenReturn('');
    await pumpScreen(tester);

    // The app bar can show a back button and a search-start button (keyed
    // 'searchBtn') alongside the filter button — the filter one is the only
    // IconButton whose icon is the filter AppSvgIcon asset.
    final filterButton = find.byWidgetPredicate(
      (w) =>
          w is IconButton &&
          w.icon is AppSvgIcon &&
          (w.icon as AppSvgIcon).path == AssetsConstants.filterIcon,
    );
    await tester.tap(filterButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog(
      'filter sheet title → expected: visible, actual: ${find.text(LanguageLabelKeys.filterByStatus).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.filterByStatus), findsOneWidget);
  });
}
