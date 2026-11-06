import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/bill_summary_card.dart';
import 'package:deliveryboy/features/orders/widgets/ecommerce_order_detail_items_card.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// The cards that make up the ecommerce order-detail body. They take plain
/// props, so each is exercised directly; the screen that assembles them is
/// covered by the orders integration flow.
void main() {
  late EcommerceOrderDataModel order;

  setUp(() async {
    // Dates are formatted through AppDateFormatter, which reads the
    // server-provided format out of SettingsHiveBox.
    await HiveTestHelper.setUp(settingsBox);

    final response =
        jsonDecode(
              File(
                'test/fixtures/orders/ecommerce_order_detail.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final row = Map<String, dynamic>.from(
      (response['data'] as List).first as Map,
    );
    // Blank the product image: a network image loader schedules a timer that
    // outlives the widget tree and fails the test with "A Timer is still
    // pending" after the assertions have already passed.
    row['image'] = '';
    order = EcommerceOrderDataModel.fromJson(row);
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(820, 2000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(pumpTestWidget(SingleChildScrollView(child: card)));
    await tester.pump();
  }

  group('EcommerceOrderDetailItemsCard', () {
    testWidgets('shows the item this row is for', (tester) async {
      printTestDivider('shows the item this row is for');
      await pumpCard(
        tester,
        EcommerceOrderDetailItemsCard(order: order, symbol: '₹'),
      );

      printTestLog('product → expected: "${order.productName}" visible');
      expect(find.textContaining(order.productName!), findsWidgets);
    });

    testWidgets('renders when the order carries no other items', (
      tester,
    ) async {
      printTestDivider('renders when the order carries no other items');
      // The ecommerce list is per order item; `otherItems` is the rest of the
      // same order and is often absent.
      order.otherItems = null;
      await pumpCard(
        tester,
        EcommerceOrderDetailItemsCard(order: order, symbol: '₹'),
      );

      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
      expect(find.textContaining(order.productName!), findsWidgets);
    });
  });

  group('EcommerceOrderBillingCard', () {
    testWidgets('summarises the payment', (tester) async {
      printTestDivider('EcommerceOrderBillingCard summarises the payment');
      await pumpCard(
        tester,
        BillSummaryCard(
          type: BillOrderType.ecommerce,
          ecommerceOrder: order,
          symbol: '₹',
        ),
      );

      printTestLog(
        'payment summary → expected: 1, actual: ${find.byType(PaymentSummarySection).evaluate().length}',
      );
      expect(find.byType(PaymentSummarySection), findsOneWidget);
    });

    testWidgets('drops the collect callout for a delivered COD item', (
      tester,
    ) async {
      printTestDivider('drops the collect callout for a delivered COD item');
      // Every row in the fixture is already delivered (status 6).
      printTestLog('activeStatus → expected: 6, actual: ${order.activeStatus}');
      expect(order.activeStatus, 6);
      await pumpCard(
        tester,
        BillSummaryCard(
          type: BillOrderType.ecommerce,
          ecommerceOrder: order,
          symbol: '₹',
        ),
      );

      printTestLog(
        'collect callout → expected: absent, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsNothing);
    });

    testWidgets('asks for cash while the same item is out for delivery', (
      tester,
    ) async {
      printTestDivider('asks for cash while the same item is out for delivery');
      order.activeStatus = 5;
      order.paymentMethod = 'COD';
      await pumpCard(
        tester,
        BillSummaryCard(
          type: BillOrderType.ecommerce,
          ecommerceOrder: order,
          symbol: '₹',
        ),
      );

      printTestLog(
        'collect callout → expected: 1, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsOneWidget);
    });
  });
}
