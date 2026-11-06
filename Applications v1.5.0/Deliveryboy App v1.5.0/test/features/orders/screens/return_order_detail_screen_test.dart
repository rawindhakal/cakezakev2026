import 'dart:convert';
import 'dart:io';

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
import 'package:deliveryboy/features/orders/screens/return_order_detail_screen.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// ReturnOrderDetailScreen builds its own ReturnOrderDetailCubit internally,
/// keyed off the route argument. Its loaded body (ReturnOrderDetailBody) is
/// already covered widget-by-widget in return_order_detail_body_test.dart —
/// this only exercises the screen's own loading/error/retry shell.
void main() {
  late FakeApiAdapter adapter;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/orders/return_order_detail.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({ApiEndpoints.returnRequests: (_) => fixture()});
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
    String returnRequestId = '23',
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
        builder: (_) => const ReturnOrderDetailScreen(),
        settings: RouteSettings(arguments: returnRequestId),
      ),
    );
    await tester.pump();
    return navigatorKey;
  }

  testWidgets('loads the return request and renders its number', (tester) async {
    printTestDivider('ReturnOrderDetailScreen loads the return request and renders its number');
    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: return_requests requested with the route id, actual: ${adapter.requests.last.queryParameters}');
    expect(adapter.requestedPaths, contains(ApiEndpoints.returnRequests));
    expect(adapter.requests.last.queryParameters['return_request_id'], '23');
    expect(find.byType(OrderDetailSkeleton), findsNothing);
    expect(find.textContaining('RET-00023'), findsWidgets);

    // OrderStatusSlideBar.returnOrder in the body also fetches order_statuses
    // in the background — settle it before the test ends.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('an error response shows the retry state, and retry reloads', (tester) async {
    printTestDivider('ReturnOrderDetailScreen an error response shows the retry state, and retry reloads');
    adapter = FakeApiAdapter({
      ApiEndpoints.returnRequests: (_) => {'status': 0, 'message': 'Return request not found'},
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: 1 request so far, actual: ${adapter.requestedPaths.length}');
    expect(adapter.requestedPaths.length, 1);
    expect(find.text('Return request not found'), findsOneWidget);

    await tester.tap(find.text('retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('expected: retried → 2+ requests, actual: ${adapter.requestedPaths.length}');
    expect(adapter.requestedPaths.length, greaterThanOrEqualTo(2));
  });
}
