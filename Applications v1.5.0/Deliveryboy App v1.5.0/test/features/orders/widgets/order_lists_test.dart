import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/ecommerce_order_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_list_view.dart';
import 'package:deliveryboy/features/orders/widgets/return_order_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// Covers the shared [OrderListView] shell with each feature's real item
/// type and card widget (quick order, return request, ecommerce order),
/// same as how orders_screen.dart wires them up directly. The pagination
/// footer/refresh plumbing itself lives in OrderListView and is exercised
/// generically here rather than three times over.
void main() {
  late List<OrderData> orders;
  late List<ReturnRequestData> returnOrders;
  late List<EcommerceOrderDataModel> ecommerceOrders;

  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);

    List<Map<String, dynamic>> load(String path) =>
        ((jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    orders = load('test/fixtures/orders/orders_list.json').map(OrderData.fromJson).toList();
    returnOrders = load(
      'test/fixtures/orders/return_orders_list.json',
    ).map(ReturnRequestData.fromJson).toList();
    ecommerceOrders = load(
      'test/fixtures/orders/ecommerce_orders_list.json',
    ).map(EcommerceOrderDataModel.fromJson).toList();
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('OrderListView', () {
    testWidgets('shows the empty state when items is empty', (tester) async {
      printTestDivider('OrderListView shows the empty state when items is empty');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<int>(
            items: const [],
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'Nothing here',
            emptySubtitle: 'Come back later',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, item, index) => Text('item $item'),
          ),
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      printTestLog('expected: empty title visible, actual: found');
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders each item and a trailing loading footer when isLoadingMore', (tester) async {
      printTestDivider('OrderListView renders each item and a trailing loading footer when isLoadingMore');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<int>(
            items: const [1, 2, 3],
            isLoadingMore: true,
            hasMore: true,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'Nothing here',
            emptySubtitle: 'Come back later',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, item, index) => Text('item $item'),
          ),
        ),
      );

      expect(find.text('item 1'), findsOneWidget);
      expect(find.text('item 3'), findsOneWidget);
      printTestLog('expected: 3 items rendered, actual: found');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      printTestLog('expected: loading footer visible, actual: found');
    });
  });

  group('OrderListView<OrderData>', () {
    testWidgets('renders a card per quick order', (tester) async {
      printTestDivider('OrderListView<OrderData> renders a card per quick order');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<OrderData>(
            items: orders,
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'No orders found',
            emptySubtitle: 'You have no orders yet',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, order, index) => OrderCard(order: order),
          ),
        ),
      );
      await tester.pump();

      printTestLog('expected: ${orders.length} order numbers visible, actual: found');
      expect(find.text(orders.first.orderNumber ?? ''), findsOneWidget);
    });

    testWidgets('shows the no-orders empty state when there are none', (tester) async {
      printTestDivider('OrderListView<OrderData> shows the no-orders empty state when there are none');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<OrderData>(
            items: const [],
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'No orders found',
            emptySubtitle: 'You have no orders yet',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, order, index) => OrderCard(order: order),
          ),
        ),
      );

      expect(find.byType(ListView), findsNothing);
      printTestLog('expected: no list rendered for an empty order set, actual: none found');
    });
  });

  group('OrderListView<ReturnRequestData>', () {
    testWidgets('renders a card per return request', (tester) async {
      printTestDivider('OrderListView<ReturnRequestData> renders a card per return request');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<ReturnRequestData>(
            items: returnOrders,
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'No return requests',
            emptySubtitle: 'You have no return requests yet',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, order, index) => ReturnOrderCard(order: order),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      printTestLog('expected: return-request list rendered, actual: found');
    });

    testWidgets('shows the no-return-requests empty state when there are none', (tester) async {
      printTestDivider('OrderListView<ReturnRequestData> shows the no-return-requests empty state when there are none');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<ReturnRequestData>(
            items: const [],
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'No return requests',
            emptySubtitle: 'You have no return requests yet',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, order, index) => ReturnOrderCard(order: order),
          ),
        ),
      );

      expect(find.byType(ListView), findsNothing);
      printTestLog('expected: no list rendered for an empty return set, actual: none found');
    });
  });

  group('OrderListView<EcommerceOrderDataModel>', () {
    testWidgets('renders a card per ecommerce order', (tester) async {
      printTestDivider('OrderListView<EcommerceOrderDataModel> renders a card per ecommerce order');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<EcommerceOrderDataModel>(
            items: ecommerceOrders,
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'No orders found',
            emptySubtitle: 'You have no orders yet',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, order, index) => EcommerceOrderCard(order: order),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      printTestLog('expected: ecommerce order list rendered, actual: found');
    });

    testWidgets('shows the no-orders empty state when there are none', (tester) async {
      printTestDivider('OrderListView<EcommerceOrderDataModel> shows the no-orders empty state when there are none');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderListView<EcommerceOrderDataModel>(
            items: const [],
            isLoadingMore: false,
            hasMore: false,
            scrollController: ScrollController(),
            onRefresh: () async {},
            emptyTitle: 'No orders found',
            emptySubtitle: 'You have no orders yet',
            emptyImagePath: 'assets/images/no_order_found.svg',
            itemBuilder: (context, order, index) => EcommerceOrderCard(order: order),
          ),
        ),
      );

      expect(find.byType(ListView), findsNothing);
      printTestLog('expected: no list rendered for an empty ecommerce order set, actual: none found');
    });
  });
}
