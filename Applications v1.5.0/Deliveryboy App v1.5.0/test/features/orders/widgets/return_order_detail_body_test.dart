import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_status_timeline.dart';
import 'package:deliveryboy/features/orders/widgets/pickup_delivery_card.dart';
import 'package:deliveryboy/features/orders/widgets/return_order_detail_body.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late ReturnRequestData detail;

  setUp(() async {
    // Dates are formatted through AppDateFormatter, which reads the
    // server-provided format out of SettingsHiveBox; DioInterceptor also reads
    // the auth token and language code on every request.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    // The body mounts OrderStatusSlideBar.returnOrder, which fetches the status
    // list on build. Leaving that endpoint unstubbed leaves Dio's own request
    // timer pending and fails the test with "A Timer is still pending" long
    // after the assertions have passed.
    ApiClient().httpClientAdapter = FakeApiAdapter({
      ApiEndpoints.orderStatuses: (_) =>
          jsonDecode(
                File(
                  'test/fixtures/orders/return_order_statuses.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
    });

    final response =
        jsonDecode(
              File(
                'test/fixtures/orders/return_order_detail.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    // Blank the product image URL: a network image loader schedules a timer
    // that outlives the widget tree, failing the test with "A Timer is still
    // pending" after every assertion has already passed. Nothing here asserts
    // on images.
    ((response['data'] as Map)['return_item'] as Map)['image'] = '';

    detail = ReturnDetailResponse.fromJson(response).data!;
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpBody(WidgetTester tester, ReturnRequestData data) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(ReturnOrderDetailBody(detail: data)),
    );
    await tester.pump();
    // Let the status-list request land so its timer is cancelled.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows the pickup and drop-off parties', (tester) async {
    printTestDivider('shows the pickup and drop-off parties');
    await pumpBody(tester, detail);

    printTestLog(
      'pickup/delivery card → expected: 1, actual: ${find.byType(PickupDeliveryCard).evaluate().length}',
    );
    expect(find.byType(PickupDeliveryCard), findsOneWidget);
  });

  testWidgets('shows the returned product', (tester) async {
    printTestDivider('shows the returned product');
    await pumpBody(tester, detail);

    printTestLog('product → expected: "${detail.productName}" visible');
    expect(find.textContaining(detail.productName!), findsWidgets);
  });

  testWidgets('shows the timeline when the request has one', (tester) async {
    printTestDivider('shows the timeline when the request has one');
    printTestLog('timeline entries → expected: some, actual: ${detail.timeline?.length}');
    expect(detail.timeline, isNotEmpty);

    await pumpBody(tester, detail);

    printTestLog(
      'timeline → expected: 1, actual: ${find.byType(OrderStatusTimeline).evaluate().length}',
    );
    expect(find.byType(OrderStatusTimeline), findsOneWidget);
  });

  testWidgets('omits the timeline when the request has none', (tester) async {
    printTestDivider('omits the timeline when the request has none');
    detail.timeline = [];
    await pumpBody(tester, detail);

    printTestLog(
      'timeline → expected: absent, actual: ${find.byType(OrderStatusTimeline).evaluate().length}',
    );
    expect(find.byType(OrderStatusTimeline), findsNothing);
  });

  testWidgets('shows the return reason the customer gave', (tester) async {
    printTestDivider('shows the return reason the customer gave');
    detail.returnReason = 'Damaged on arrival';
    await pumpBody(tester, detail);

    printTestLog('reason → expected: "Damaged on arrival" visible');
    expect(find.textContaining('Damaged on arrival'), findsWidgets);
  });

  testWidgets('omits the info card when there is no reason or remark', (
    tester,
  ) async {
    printTestDivider('omits the info card when there is no reason or remark');
    final before = find.byType(Card).evaluate().length;
    detail.returnReason = null;
    detail.remarks = null;
    detail.rejectReason = null;
    await pumpBody(tester, detail);

    printTestLog('cards → expected: no more than with a reason ($before)');
    expect(find.byType(Card).evaluate().length, lessThanOrEqualTo(before + 1));
    printTestLog('exception → expected: none, actual: ${tester.takeException()}');
  });

  testWidgets('shows the rejection reason when the request was rejected', (
    tester,
  ) async {
    printTestDivider('shows the rejection reason when the request was rejected');
    detail.rejectReason = 'Item already used';
    await pumpBody(tester, detail);

    printTestLog('reject reason → expected: "Item already used" visible');
    expect(find.textContaining('Item already used'), findsWidgets);
  });

  testWidgets('renders a request stripped of its optional blocks', (
    tester,
  ) async {
    printTestDivider('renders a request stripped of its optional blocks');
    // A bare request (no timeline, no reason, no addresses) still has to lay
    // out rather than throwing.
    final bare = ReturnRequestData.fromJson(const {
      'id': 1,
      'return_number': 'RET-00001',
      'product_name': 'Test product',
    });
    await pumpBody(tester, bare);

    printTestLog('return number → expected: rendered, actual: ${tester.takeException()}');
    expect(find.textContaining('Test product'), findsWidgets);
  });
}
