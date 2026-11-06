import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/status_chip.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/ecommerce_order_card.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';
import 'package:deliveryboy/features/orders/widgets/return_order_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late List<EcommerceOrderDataModel> ecommerceOrders;
  late List<ReturnRequestData> returnOrders;

  // Both cards format their date through AppDateFormatter, which reads the
  // server-provided format out of SettingsHiveBox.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);

    List<dynamic> rowsOf(String fixture) =>
        (jsonDecode(
                  File(
                    'test/fixtures/orders/$fixture.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['data']
            as List;

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
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(pumpTestWidget(SingleChildScrollView(child: card)));
    await tester.pump();
  }

  group('EcommerceOrderCard', () {
    testWidgets('shows the order number, status and total', (tester) async {
      printTestDivider('EcommerceOrderCard shows the order number, status and total');
      final order = ecommerceOrders.first;
      await pumpCard(tester, EcommerceOrderCard(order: order));

      printTestLog('order number → expected: "${order.orderNumber}" visible');
      expect(find.text('${order.orderNumber}'), findsOneWidget);
      printTestLog('status chip → expected: 1, actual: ${find.byType(StatusChip).evaluate().length}');
      expect(find.byType(StatusChip), findsOneWidget);
      // finalTotal 272.05 renders rounded.
      printTestLog('total → expected: "₹272" visible');
      expect(find.text('₹272'), findsOneWidget);
    });

    testWidgets('shows no collect callout for a delivered COD item', (
      tester,
    ) async {
      printTestDivider('EcommerceOrderCard shows no collect callout for a delivered COD item');
      // Every row in the fixture is already delivered.
      final order = ecommerceOrders.first;
      printTestLog('activeStatus → expected: 6 (delivered), actual: ${order.activeStatus}');
      expect(order.activeStatus, 6);
      await pumpCard(tester, EcommerceOrderCard(order: order));

      printTestLog(
        'callout → expected: absent, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsNothing);
    });

    testWidgets('asks for cash once the same item is still out for delivery', (
      tester,
    ) async {
      printTestDivider('EcommerceOrderCard asks for cash once the same item is still out for delivery');
      final order = ecommerceOrders.first;
      // 5 == out for delivery, so the COD amount is still to be collected.
      order.activeStatus = 5;
      await pumpCard(tester, EcommerceOrderCard(order: order));

      printTestLog(
        'callout → expected: 1, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      printTestDivider('EcommerceOrderCard invokes onTap when tapped');
      var tapped = false;
      await pumpCard(
        tester,
        EcommerceOrderCard(
          order: ecommerceOrders.first,
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(EcommerceOrderCard));
      await tester.pump();

      printTestLog('onTap called → expected: true, actual: $tapped');
      expect(tapped, isTrue);
    });

    testWidgets('falls back to the item id when there is no order number', (
      tester,
    ) async {
      printTestDivider('EcommerceOrderCard falls back to the item id when there is no order number');
      final order = ecommerceOrders.first;
      order.orderNumber = null;
      await pumpCard(tester, EcommerceOrderCard(order: order));

      printTestLog('id → expected: "${order.id}" visible');
      expect(find.text('${order.id}'), findsOneWidget);
    });
  });

  group('ReturnOrderCard', () {
    ReturnRequestData byId(int id) => returnOrders.firstWhere((r) => r.id == id);

    testWidgets('shows the return number and its status', (tester) async {
      printTestDivider('ReturnOrderCard shows the return number and its status');
      await pumpCard(tester, ReturnOrderCard(order: byId(23)));

      printTestLog('return number → expected: "RET-00023" visible');
      expect(find.text('RET-00023'), findsOneWidget);
      printTestLog('status chip → expected: 1, actual: ${find.byType(StatusChip).evaluate().length}');
      expect(find.byType(StatusChip), findsOneWidget);
    });

    testWidgets('shows the quantity and product on one line', (tester) async {
      printTestDivider('ReturnOrderCard shows the quantity and product on one line');
      final order = byId(23);
      await pumpCard(tester, ReturnOrderCard(order: order));

      final line = '${order.quantity} x ${order.productName}';
      printTestLog('product line → expected: "$line" visible');
      expect(find.text(line), findsOneWidget);
    });

    testWidgets('renders a request that is still out for pickup', (tester) async {
      printTestDivider('ReturnOrderCard renders a request that is still out for pickup');
      final order = byId(9);
      printTestLog('status → expected: 5, actual: ${order.status}');
      expect(order.status, 5);
      await pumpCard(tester, ReturnOrderCard(order: order));

      printTestLog('return number → expected: "${order.returnNumber}" visible');
      expect(find.text('${order.returnNumber}'), findsOneWidget);
      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      printTestDivider('ReturnOrderCard invokes onTap when tapped');
      var tapped = false;
      await pumpCard(
        tester,
        ReturnOrderCard(order: byId(23), onTap: () => tapped = true),
      );

      await tester.tap(find.byType(ReturnOrderCard));
      await tester.pump();

      printTestLog('onTap called → expected: true, actual: $tapped');
      expect(tapped, isTrue);
    });

    testWidgets('falls back to the id when there is no return number', (
      tester,
    ) async {
      printTestDivider('ReturnOrderCard falls back to the id when there is no return number');
      final order = byId(23);
      order.returnNumber = null;
      await pumpCard(tester, ReturnOrderCard(order: order));

      printTestLog('id → expected: "${order.id}" visible');
      expect(find.text('${order.id}'), findsOneWidget);
    });

    testWidgets('defaults the quantity to 1 when the API omits it', (
      tester,
    ) async {
      printTestDivider('ReturnOrderCard defaults the quantity to 1 when the API omits it');
      final order = byId(23);
      order.quantity = null;
      await pumpCard(tester, ReturnOrderCard(order: order));

      printTestLog('product line → expected: "1 x ${order.productName}" visible');
      expect(find.text('1 x ${order.productName}'), findsOneWidget);
    });
  });
}
