import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/orders/screens/ecommerce_order_detail_screen.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// EcommerceOrderDetailScreen builds its own EcommerceOrderDetailCubit (and
/// its bottom-bar OrderStatusSlideBar.ecommerce builds two more)
/// internally, keyed off the route argument — same shape as OrderDetailScreen.
void main() {
  late FakeApiAdapter adapter;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.ecomOrders: (_) => _ecommerceDetailJson(activeStatus: 6),
    });
    ApiClient().httpClientAdapter = adapter;
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<GlobalKey<NavigatorState>> pumpScreen(
    WidgetTester tester, {
    String orderItemId = '413',
  }) async {
    final connectivityCubit = MockConnectivityCubit();
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityConnected(),
    );

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      BlocProvider<ConnectivityCubit>.value(
        value: connectivityCubit,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          navigatorKey: navigatorKey,
          home: const Scaffold(),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const EcommerceOrderDetailScreen(),
        settings: RouteSettings(arguments: orderItemId),
      ),
    );
    await tester.pump();
    return navigatorKey;
  }

  testWidgets('loads the order and renders its number in the app bar', (tester) async {
    printTestDivider('EcommerceOrderDetailScreen loads the order and renders its number in the app bar');
    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: order item requested, actual: ${adapter.requestedPaths.contains(ApiEndpoints.ecomOrders)}');
    expect(adapter.requestedPaths, contains(ApiEndpoints.ecomOrders));
    expect(find.byType(OrderDetailSkeleton), findsNothing);
    // Shows once in the app bar's id line and again in the items card header.
    expect(find.text('SB-INV-00170-1'), findsWidgets);

    // Status 6 isn't in the hidden list, so OrderStatusSlideBar.ecommerce
    // fetches order_statuses in the background — settle it before the test
    // ends so it doesn't leak a pending timer into the next one.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('hides the update-status bar entirely for a cancelled order', (tester) async {
    printTestDivider('EcommerceOrderDetailScreen hides the update-status bar entirely for a cancelled order');
    // active_status 3 sits in the screen's hard-coded hidden list.
    adapter = FakeApiAdapter({
      ApiEndpoints.ecomOrders: (_) => _ecommerceDetailJson(activeStatus: 3),
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: no order_statuses fetch when the bar is hidden, actual: ${adapter.requestedPaths.contains(ApiEndpoints.orderStatuses)}');
    expect(adapter.requestedPaths, isNot(contains(ApiEndpoints.orderStatuses)));
  });

  testWidgets('an error response shows the retry state, and retry reloads', (tester) async {
    printTestDivider('EcommerceOrderDetailScreen an error response shows the retry state, and retry reloads');
    adapter = FakeApiAdapter({
      ApiEndpoints.ecomOrders: (_) => {'status': 0, 'message': 'Order not found', 'data': []},
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: 1 request so far, actual: ${adapter.requestedPaths.length}');
    expect(adapter.requestedPaths.length, 1);

    await tester.tap(find.text('retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: retried → 2+ requests, actual: ${adapter.requestedPaths.length}');
    expect(adapter.requestedPaths.length, greaterThanOrEqualTo(2));
  });
}

Map<String, dynamic> _ecommerceDetailJson({required int activeStatus}) => {
  'status': 1,
  'message': 'Success',
  'data': [
    {
      'id': 413,
      'invoice_number': 'SB-INV-00170-1',
      'order_number': 'SB-INV-00170-1',
      'order_id': 170,
      'active_status': activeStatus,
      'order_item_status': 'Delivered',
      'currency': '₹',
      'branch_info': {},
      'address': {},
    },
  ],
};
