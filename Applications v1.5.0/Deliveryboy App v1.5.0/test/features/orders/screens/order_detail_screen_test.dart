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
import 'package:deliveryboy/features/orders/screens/order_detail_screen.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// OrderDetailScreen builds its own OrderDetailCubit (and its bottom-bar
/// OrderStatusSlideBar.normal builds two more) internally, keyed off the route
/// argument — so, like the status-sheet widgets, this runs the real cubits
/// against a faked ApiClient adapter rather than injecting mocks.
void main() {
  late FakeApiAdapter adapter;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.orderById: (_) => _orderDetailJson(activeStatus: 6),
      ApiEndpoints.orderStatuses: (_) => {
        'status': 1,
        'message': 'success',
        'data': [
          {'id': 10, 'status': 'Ready for Pickup', 'status_name': 'Ready for Pickup'},
        ],
        'return_statuses': [],
      },
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
    String orderId = '187',
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
        builder: (_) => const OrderDetailScreen(),
        settings: RouteSettings(arguments: orderId),
      ),
    );
    await tester.pump();
    return navigatorKey;
  }

  testWidgets('loads the order and renders its number in the app bar', (tester) async {
    printTestDivider('OrderDetailScreen loads the order and renders its number in the app bar');
    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: order id requested, actual: ${adapter.requestedPaths.contains(ApiEndpoints.orderById)}');
    expect(adapter.requestedPaths, contains(ApiEndpoints.orderById));
    expect(find.byType(OrderDetailSkeleton), findsNothing);
    expect(find.text('SB-ORD-00187'), findsOneWidget);

    // Status 6 also isn't in the hidden list, so OrderStatusSlideBar.normal
    // fetches order_statuses in the background — let that settle too so it
    // doesn't leak a pending timer into the next test.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('hides the update-status bar entirely for a not-yet-picked-up order', (tester) async {
    printTestDivider('OrderDetailScreen hides the update-status bar entirely for a not-yet-picked-up order');
    // active_status 1 ("New") is in the screen's hard-coded hidden list —
    // there's nothing for the delivery boy to advance until it's picked up.
    adapter = FakeApiAdapter({
      ApiEndpoints.orderById: (_) => _orderDetailJson(activeStatus: 1),
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: no order_statuses fetch when the bar is hidden, actual: ${adapter.requestedPaths.contains(ApiEndpoints.orderStatuses)}');
    expect(adapter.requestedPaths, isNot(contains(ApiEndpoints.orderStatuses)));
  });

  testWidgets('an error response shows the retry state, and retry reloads', (tester) async {
    printTestDivider('OrderDetailScreen an error response shows the retry state, and retry reloads');
    adapter = FakeApiAdapter({
      ApiEndpoints.orderById: (_) => {'status': 0, 'message': 'Order not found'},
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: 1 request so far, actual: ${adapter.requestedPaths.length}');
    expect(adapter.requestedPaths.length, 1);

    // The error state renders EmptyStateWidget with a retry button — no
    // RefreshIndicator on that branch (that only wraps the loaded body).
    await tester.tap(find.text('retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: retried → 2+ requests, actual: ${adapter.requestedPaths.length}');
    expect(adapter.requestedPaths.length, greaterThanOrEqualTo(2));
  });
}

Map<String, dynamic> _orderDetailJson({required int activeStatus}) => {
  'status': 1,
  'message': 'Success',
  'data': {
    'order': {
      'id': 187,
      'order_id': 187,
      'order_number': 'SB-ORD-00187',
      'active_status': activeStatus,
      'status_name': 'Delivered',
      'order_status_name': 'Delivered',
      'currency': '₹',
      'branch_info': {},
      'address': {},
    },
    'order_items': [],
    'timeline': [],
  },
};
