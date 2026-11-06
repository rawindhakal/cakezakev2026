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
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/screens/orders_screen.dart';
import 'package:deliveryboy/features/orders/widgets/ecommerce_order_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:deliveryboy/features/orders/widgets/return_order_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockOrderCubit extends MockCubit<PaginationState<OrderData>>
    implements OrderCubit {}

class MockEcommerceOrderCubit
    extends MockCubit<PaginationState<EcommerceOrderDataModel>>
    implements EcommerceOrderCubit {}

class MockReturnOrderCubit extends MockCubit<PaginationState<ReturnRequestData>>
    implements ReturnOrderCubit {}

class MockOrderStatusListFilterCubit
    extends MockCubit<OrderStatusListFilterState>
    implements OrderStatusListFilterCubit {}

class MockReturnOrderStatusListFilterCubit
    extends MockCubit<ReturnOrderStatusListFilterState>
    implements ReturnOrderStatusListFilterCubit {}

void main() {
  late MockOrderCubit orderCubit;
  late MockEcommerceOrderCubit ecommerceCubit;
  late MockReturnOrderCubit returnCubit;
  late MockOrderStatusListFilterCubit statusFilterCubit;
  late MockReturnOrderStatusListFilterCubit returnStatusFilterCubit;
  late MockConnectivityCubit connectivityCubit;

  late List<OrderData> orders;
  late List<EcommerceOrderDataModel> ecommerceOrders;
  late List<ReturnRequestData> returnOrders;

  List<dynamic> rowsOf(String fixture) =>
      (jsonDecode(
                File('test/fixtures/orders/$fixture.json').readAsStringSync(),
              )
              as Map<String, dynamic>)['data']
          as List;

  setUp(() async {
    // The cards format dates through AppDateFormatter, which reads the
    // server-provided format out of SettingsHiveBox.
    await HiveTestHelper.setUp(settingsBox);

    orders = rowsOf('orders_list')
        .map((e) => OrderData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    ecommerceOrders = rowsOf('ecommerce_orders_list')
        .map(
          (e) => EcommerceOrderDataModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    returnOrders = rowsOf('return_orders_list')
        .map(
          (e) => ReturnRequestData.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    orderCubit = MockOrderCubit();
    ecommerceCubit = MockEcommerceOrderCubit();
    returnCubit = MockReturnOrderCubit();
    statusFilterCubit = MockOrderStatusListFilterCubit();
    returnStatusFilterCubit = MockReturnOrderStatusListFilterCubit();
    connectivityCubit = MockConnectivityCubit();

    when(() => orderCubit.loadOrders()).thenAnswer((_) async {});
    when(() => orderCubit.loadMore()).thenAnswer((_) async {});
    when(() => orderCubit.selectedStatus).thenReturn('');
    when(() => orderCubit.startDate).thenReturn(null);
    when(() => orderCubit.endDate).thenReturn(null);
    when(() => orderCubit.hasActiveFilters).thenReturn(false);
    when(
      () => orderCubit.updateFilters(
        status: any(named: 'status'),
        search: any(named: 'search'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => ecommerceCubit.loadOrders(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});
    when(() => ecommerceCubit.loadMore()).thenAnswer((_) async {});
    when(() => ecommerceCubit.selectedStatus).thenReturn('');
    // The screen ORs hasActiveFilters across all three cubits to decide
    // whether to show the filter dot; an unstubbed one returns null into a
    // bool and the whole screen fails to build.
    when(() => ecommerceCubit.hasActiveFilters).thenReturn(false);
    when(
      () => ecommerceCubit.updateFilters(
        status: any(named: 'status'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});

    when(() => returnCubit.loadOrders()).thenAnswer((_) async {});
    when(() => returnCubit.loadMore()).thenAnswer((_) async {});
    when(() => returnCubit.selectedStatus).thenReturn('');
    when(() => returnCubit.hasActiveFilters).thenReturn(false);
    when(
      () => returnCubit.updateFilters(
        status: any(named: 'status'),
        search: any(named: 'search'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => statusFilterCubit.orderStatusesFilter(channel: any(named: 'channel')),
    ).thenAnswer((_) async {});
    when(
      () => returnStatusFilterCubit.returnOrderStatusesFilter(),
    ).thenAnswer((_) async {});

    whenListen(
      statusFilterCubit,
      const Stream<OrderStatusListFilterState>.empty(),
      initialState: OrderStatusListFilterLoaded([
        OrderStatusData(id: '', status: 'All', statusName: 'All'),
        OrderStatusData(id: '6', status: 'Delivered', statusName: 'Delivered'),
      ]),
    );
    whenListen(
      returnStatusFilterCubit,
      const Stream<ReturnOrderStatusListFilterState>.empty(),
      initialState: ReturnOrderStatusListFilterLoaded([
        OrderStatusData(id: '', status: 'All', statusName: 'All'),
      ]),
    );
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<OrderData>? quickState,
    PaginationState<EcommerceOrderDataModel>? ecommerceState,
    PaginationState<ReturnRequestData>? returnState,
    ConnectivityState? connectivity,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Wider than a phone on purpose: with translations unloaded the filter
    // sheet's type chips render their raw keys ("ecommerce_tab"), which are
    // longer than the real labels and overflow a 500px row.
    tester.view.physicalSize = const Size(820, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      orderCubit,
      const Stream<PaginationState<OrderData>>.empty(),
      initialState:
          quickState ?? PaginationLoaded<OrderData>(data: orders, total: 27),
    );
    whenListen(
      ecommerceCubit,
      const Stream<PaginationState<EcommerceOrderDataModel>>.empty(),
      initialState:
          ecommerceState ??
          PaginationLoaded<EcommerceOrderDataModel>(
            data: ecommerceOrders,
            total: 5,
          ),
    );
    whenListen(
      returnCubit,
      const Stream<PaginationState<ReturnRequestData>>.empty(),
      initialState:
          returnState ??
          PaginationLoaded<ReturnRequestData>(data: returnOrders, total: 8),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<OrderCubit>.value(value: orderCubit),
          BlocProvider<EcommerceOrderCubit>.value(value: ecommerceCubit),
          BlocProvider<ReturnOrderCubit>.value(value: returnCubit),
          BlocProvider<OrderStatusListFilterCubit>.value(value: statusFilterCubit),
          BlocProvider<ReturnOrderStatusListFilterCubit>.value(
            value: returnStatusFilterCubit,
          ),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // OrdersScreen builds its own AppScaffold.
        child: pumpTestWidget(const OrdersScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loads all three lists and both status filters on first build', (
    tester,
  ) async {
    printTestDivider('loads all three lists and both status filters on first build');
    await pumpScreen(tester);

    verify(() => orderCubit.loadOrders()).called(1);
    verify(
      () => ecommerceCubit.loadOrders(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).called(1);
    verify(() => returnCubit.loadOrders()).called(1);
    // The quick tab is the one shown first, so its channel is requested.
    verify(
      () => statusFilterCubit.orderStatusesFilter(channel: AppConstants.quick),
    ).called(1);
    verify(() => returnStatusFilterCubit.returnOrderStatusesFilter()).called(1);
    printTestLog('initial loads → all verified');
  });

  testWidgets('opens on the quick-orders tab', (tester) async {
    printTestDivider('opens on the quick-orders tab');
    await pumpScreen(tester);

    printTestLog('order cards → expected: some, actual: ${find.byType(OrderCard).evaluate().length}');
    expect(find.byType(OrderCard), findsWidgets);
    // The other tabs' cards live in an IndexedStack and are offstage, so the
    // default finder does not see them.
    printTestLog('ecommerce cards → expected: none visible, actual: ${find.byType(EcommerceOrderCard).evaluate().length}');
    expect(find.byType(EcommerceOrderCard), findsNothing);
    printTestLog('return cards → expected: none visible, actual: ${find.byType(ReturnOrderCard).evaluate().length}');
    expect(find.byType(ReturnOrderCard), findsNothing);
  });

  testWidgets('shows the skeleton while the quick list loads', (tester) async {
    printTestDivider('shows the skeleton while the quick list loads');
    await pumpScreen(
      tester,
      quickState: const PaginationLoading<OrderData>(),
    );

    printTestLog('skeleton → expected: 1, actual: ${find.byType(OrderListSkeleton).evaluate().length}');
    expect(find.byType(OrderListSkeleton), findsOneWidget);
    printTestLog('cards → expected: none, actual: ${find.byType(OrderCard).evaluate().length}');
    expect(find.byType(OrderCard), findsNothing);
  });

  testWidgets('shows the error state with a retry when the quick list fails', (
    tester,
  ) async {
    printTestDivider('shows the error state with a retry when the quick list fails');
    await pumpScreen(
      tester,
      quickState: const PaginationError<OrderData>('Orders unavailable'),
    );

    printTestLog('empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}');
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Orders unavailable" visible');
    expect(find.text('Orders unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state refetches the quick list', (
    tester,
  ) async {
    printTestDivider('retry on the error state refetches the quick list');
    await pumpScreen(
      tester,
      quickState: const PaginationError<OrderData>('Orders unavailable'),
    );

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    // Once from initState, once from the retry.
    verify(() => orderCubit.loadOrders()).called(2);
    printTestLog('refetch → verified');
  });

  testWidgets('replaces the list with the offline screen when disconnected', (
    tester,
  ) async {
    printTestDivider('replaces the list with the offline screen when disconnected');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    printTestLog('offline screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}');
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog('cards → expected: none, actual: ${find.byType(OrderCard).evaluate().length}');
    expect(find.byType(OrderCard), findsNothing);
  });

  /// The order type is chosen inside the filter bottom sheet, not from a tab
  /// bar on the screen: open the sheet, pick a type chip, then Apply.
  Future<void> pickOrderType(WidgetTester tester, String typeLabel) async {
    await tester.tap(find.byTooltip(LanguageLabelKeys.filters));
    await tester.pump();
    // The sheet's children slide in; a still-animating chip is not
    // hit-testable, so wait out the entrance before tapping.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text(typeLabel));
    await tester.pump();
    await tester.tap(find.text(LanguageLabelKeys.apply));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('switching to the ecommerce type shows its cards and channel', (
    tester,
  ) async {
    printTestDivider('switching to the ecommerce type shows its cards and channel');
    await pumpScreen(tester);

    await pickOrderType(tester, LanguageLabelKeys.ecommerceTab);

    printTestLog('ecommerce cards → expected: some, actual: ${find.byType(EcommerceOrderCard).evaluate().length}');
    expect(find.byType(EcommerceOrderCard), findsWidgets);
    printTestLog('quick cards → expected: none visible, actual: ${find.byType(OrderCard).evaluate().length}');
    expect(find.byType(OrderCard), findsNothing);
    // Switching type refetches the status list for that channel.
    verify(
      () => statusFilterCubit.orderStatusesFilter(
        channel: AppConstants.ecommerce,
      ),
    ).called(1);
  });

  testWidgets('switching to the returns type shows return cards', (
    tester,
  ) async {
    printTestDivider('switching to the returns type shows return cards');
    await pumpScreen(tester);

    await pickOrderType(tester, LanguageLabelKeys.returnsTab);

    printTestLog('return cards → expected: some, actual: ${find.byType(ReturnOrderCard).evaluate().length}');
    expect(find.byType(ReturnOrderCard), findsWidgets);
    // The returns type reloads its own status filter, not the order one.
    verify(() => returnStatusFilterCubit.returnOrderStatusesFilter()).called(2);
  });

  testWidgets('re-picking the current type does not refetch its statuses', (
    tester,
  ) async {
    printTestDivider('re-picking the current type does not refetch its statuses');
    await pumpScreen(tester);

    await pickOrderType(tester, LanguageLabelKeys.quickTab);

    // Still only the one call from initState — _changeType returns early when
    // the type has not actually changed.
    verify(
      () => statusFilterCubit.orderStatusesFilter(channel: AppConstants.quick),
    ).called(1);
    printTestLog('no refetch → verified');
  });

  testWidgets('applying a filter pushes the search text into the quick cubit', (
    tester,
  ) async {
    printTestDivider('applying a filter pushes the search text into the quick cubit');
    await pumpScreen(tester);

    await pickOrderType(tester, LanguageLabelKeys.quickTab);

    verify(
      () => orderCubit.updateFilters(
        status: any(named: 'status'),
        search: any(named: 'search'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).called(1);
    printTestLog('filters applied → verified');
  });
}

