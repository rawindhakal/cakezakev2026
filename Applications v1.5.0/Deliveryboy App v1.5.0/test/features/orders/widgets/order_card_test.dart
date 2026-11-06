import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/status_chip.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_card.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late List<OrderData> orders;

  // The card formats the order date through AppDateFormatter, which reads the
  // server-provided format out of SettingsHiveBox.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    final response =
        jsonDecode(
              File('test/fixtures/orders/orders_list.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    orders = (response['data'] as List)
        .map((e) => OrderData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  OrderData byNumber(String number) =>
      orders.firstWhere((o) => o.orderNumber == number);

  Future<void> pumpCard(
    WidgetTester tester,
    OrderData order, {
    VoidCallback? onTap,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(child: OrderCard(order: order, onTap: onTap)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the order number and its status chip', (tester) async {
    printTestDivider('shows the order number and its status chip');
    await pumpCard(tester, byNumber('SB-ORD-00006'));

    printTestLog('order number → expected: "SB-ORD-00006" visible');
    expect(find.text('SB-ORD-00006'), findsOneWidget);
    printTestLog('status chip → expected: 1, actual: ${find.byType(StatusChip).evaluate().length}');
    expect(find.byType(StatusChip), findsOneWidget);
    printTestLog('status name → expected: "Out For Delivery" visible');
    expect(find.text('Out For Delivery'), findsOneWidget);
  });

  testWidgets('lists at most two items and counts the rest', (tester) async {
    printTestDivider('lists at most two items and counts the rest');
    // This order has 3 items, so two render and the third is summarised.
    final order = byNumber('SB-ORD-00006');
    await pumpCard(tester, order);

    printTestLog('items on the order → expected: 3, actual: ${order.items?.length}');
    expect(order.items?.length, 3);
    for (final item in order.items!.take(2)) {
      final label = '${item.quantity} x ${item.productName}';
      printTestLog('item row → expected: "$label" visible');
      expect(find.text(label), findsOneWidget);
    }
    printTestLog('overflow label → expected: "+1 more item" visible');
    expect(find.text('+1 more item'), findsOneWidget);
  });

  testWidgets('pluralises the overflow label for more than one extra item', (
    tester,
  ) async {
    printTestDivider('pluralises the overflow label for more than one extra item');
    final order = byNumber('SB-ORD-00006');
    // Duplicate the items so four exist and two overflow.
    order.items = [...order.items!, order.items!.first];
    await pumpCard(tester, order);

    printTestLog('overflow label → expected: "+2 more items" visible');
    expect(find.text('+2 more items'), findsOneWidget);
  });

  testWidgets('shows no overflow label when every item fits', (tester) async {
    printTestDivider('shows no overflow label when every item fits');
    // This order has a single item.
    await pumpCard(tester, byNumber('SB-ORD-00186'));

    printTestLog('overflow label → expected: absent');
    expect(find.textContaining('more item'), findsNothing);
  });

  testWidgets('asks the rider to collect cash on an undelivered COD order', (
    tester,
  ) async {
    printTestDivider('asks the rider to collect cash on an undelivered COD order');
    // SB-ORD-00157 is COD and still out for delivery.
    final order = byNumber('SB-ORD-00157');
    await pumpCard(tester, order);

    printTestLog(
      'collect callout → expected: 1, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
    );
    expect(find.byType(CollectFromCustomerCallout), findsOneWidget);
  });

  testWidgets('drops the collect callout once the order is delivered', (
    tester,
  ) async {
    printTestDivider('drops the collect callout once the order is delivered');
    // SB-ORD-00187 is COD but already delivered — the cash is in already.
    await pumpCard(tester, byNumber('SB-ORD-00187'));

    printTestLog(
      'collect callout → expected: absent, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
    );
    expect(find.byType(CollectFromCustomerCallout), findsNothing);
  });

  testWidgets('shows no collect callout on a prepaid order', (tester) async {
    printTestDivider('shows no collect callout on a prepaid order');
    // SB-ORD-00006 is paid by Razorpay.
    await pumpCard(tester, byNumber('SB-ORD-00006'));

    printTestLog(
      'collect callout → expected: absent, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
    );
    expect(find.byType(CollectFromCustomerCallout), findsNothing);
  });

  testWidgets('shows the total rounded to whole currency units', (tester) async {
    printTestDivider('shows the total rounded to whole currency units');
    // finalTotal 246.3 renders as ₹246 — the card trims the paise.
    await pumpCard(tester, byNumber('SB-ORD-00006'));

    printTestLog('total → expected: "₹246" visible');
    expect(find.text('₹246'), findsOneWidget);
  });

  testWidgets('adds the wallet amount into the displayed total', (tester) async {
    printTestDivider('adds the wallet amount into the displayed total');
    // SB-ORD-00142 was fully paid from the wallet: finalTotal is 0 but the
    // order was worth 103.5, so the card shows the wallet amount, not zero.
    final order = byNumber('SB-ORD-00142');
    printTestLog('walletBalance → expected: 103.5, actual: ${order.walletBalance}');
    expect(order.walletBalance, 103.5);
    await pumpCard(tester, order);

    printTestLog('total → expected: "₹104" (103.5 rounded) visible');
    expect(find.text('₹104'), findsOneWidget);
  });

  testWidgets('invokes onTap when the card is tapped', (tester) async {
    printTestDivider('invokes onTap when the card is tapped');
    var tapped = false;
    await pumpCard(tester, byNumber('SB-ORD-00006'), onTap: () => tapped = true);

    await tester.tap(find.byType(OrderCard));
    await tester.pump();

    printTestLog('onTap called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });

  testWidgets('is inert when no onTap is given', (tester) async {
    printTestDivider('is inert when no onTap is given');
    await pumpCard(tester, byNumber('SB-ORD-00006'));

    // Tapping a card with no handler must not throw.
    await tester.tap(find.byType(OrderCard));
    await tester.pump();

    printTestLog('exception → expected: none, actual: ${tester.takeException()}');
  });

  testWidgets('falls back to the numeric id when there is no order number', (
    tester,
  ) async {
    printTestDivider('falls back to the numeric id when there is no order number');
    final order = byNumber('SB-ORD-00006');
    order.orderNumber = null;
    await pumpCard(tester, order);

    printTestLog('id → expected: "${order.id}" visible');
    expect(find.text('${order.id}'), findsOneWidget);
  });
}
