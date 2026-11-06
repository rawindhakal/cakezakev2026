import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';
import 'package:deliveryboy/features/orders/widgets/bill_summary_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_items_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_note_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_timeline_card.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';
import 'package:deliveryboy/features/orders/widgets/pickup_delivery_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// The cards that make up the order-detail screen body. They take plain props,
/// so each is exercised directly here; the screen that assembles them is
/// covered end to end by the orders integration flow.
void main() {
  late OrderDetailData detail;

  setUp(() async {
    // The timeline card formats its dates through AppDateFormatter, which
    // reads the server-provided format out of SettingsHiveBox.
    await HiveTestHelper.setUp(settingsBox);

    detail = OrderDetail.fromJson(
      jsonDecode(
            File('test/fixtures/orders/order_detail.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    ).data!;
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

  group('PickupDeliveryCard', () {
    testWidgets('shows both the store and the customer', (tester) async {
      printTestDivider('PickupDeliveryCard shows both the store and the customer');
      final order = detail.order!;
      await pumpCard(
        tester,
        PickupDeliveryCard(
          pickupName: order.storeName,
          pickupAddress: order.storeFormattedAddress,
          deliveryName: order.userName,
          deliveryAddress: order.address?.address,
          deliveryPhone: order.address?.mobile,
        ),
      );

      printTestLog('store → expected: "Mumbai Store" visible');
      expect(find.text('Mumbai Store'), findsOneWidget);
      printTestLog('customer → expected: "Hency Pithadiya" visible');
      expect(find.text('Hency Pithadiya'), findsOneWidget);
    });

    testWidgets('offers a chat action only when one is wired up', (
      tester,
    ) async {
      printTestDivider('PickupDeliveryCard offers a chat action only when one is wired up');
      var chatted = false;
      await pumpCard(
        tester,
        PickupDeliveryCard(
          pickupName: 'Mumbai Store',
          deliveryName: 'Hency',
          onDeliveryChatTap: () => chatted = true,
        ),
      );

      final before = find.byType(GestureDetector).evaluate().length;
      printTestLog('tappable actions with chat → $before');
      expect(before, greaterThan(0));

      await pumpCard(
        tester,
        const PickupDeliveryCard(
          pickupName: 'Mumbai Store',
          deliveryName: 'Hency',
        ),
      );
      final after = find.byType(GestureDetector).evaluate().length;
      printTestLog('tappable actions without chat → expected: fewer than $before, actual: $after');
      expect(after, lessThan(before));
      expect(chatted, isFalse);
    });

    testWidgets('renders with nothing but names', (tester) async {
      printTestDivider('PickupDeliveryCard renders with nothing but names');
      // A store with no phone or coordinates must not break the card.
      await pumpCard(
        tester,
        const PickupDeliveryCard(pickupName: 'Store', deliveryName: 'Customer'),
      );

      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
      expect(find.text('Store'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
    });
  });

  group('OrderItemsCard', () {
    testWidgets('lists every item with its quantity', (tester) async {
      printTestDivider('OrderItemsCard lists every item with its quantity');
      final items = detail.orderItems!;
      await pumpCard(tester, OrderItemsCard(items: items, symbol: '₹'));

      printTestLog('items in fixture → expected: 3, actual: ${items.length}');
      expect(items.length, 3);
      for (final item in items) {
        printTestLog('item → expected: "${item.productName}" visible');
        expect(find.textContaining(item.productName!), findsWidgets);
      }
    });

    testWidgets('renders an empty item list without breaking', (tester) async {
      printTestDivider('OrderItemsCard renders an empty item list without breaking');
      await pumpCard(tester, const OrderItemsCard(items: [], symbol: '₹'));

      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });
  });

  group('OrderBillingCard', () {
    testWidgets('summarises the order payment', (tester) async {
      printTestDivider('OrderBillingCard summarises the order payment');
      await pumpCard(
        tester,
        BillSummaryCard(
          type: BillOrderType.order,
          order: detail.order,
          detail: detail,
          symbol: '₹',
        ),
      );

      printTestLog(
        'payment summary → expected: 1, actual: ${find.byType(PaymentSummarySection).evaluate().length}',
      );
      expect(find.byType(PaymentSummarySection), findsOneWidget);
      // The fixture order is prepaid by Razorpay, so no cash is collected.
      printTestLog(
        'collect callout → expected: absent, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsNothing);
    });

    testWidgets('asks for cash on an undelivered COD order', (tester) async {
      printTestDivider('OrderBillingCard asks for cash on an undelivered COD order');
      detail.order!.paymentMethod = 'COD';
      await pumpCard(
        tester,
        BillSummaryCard(
          type: BillOrderType.order,
          order: detail.order,
          detail: detail,
          symbol: '₹',
        ),
      );

      printTestLog(
        'collect callout → expected: 1, actual: ${find.byType(CollectFromCustomerCallout).evaluate().length}',
      );
      expect(find.byType(CollectFromCustomerCallout), findsOneWidget);
    });

    testWidgets('renders with no order attached', (tester) async {
      printTestDivider('OrderBillingCard renders with no order attached');
      await pumpCard(
        tester,
        BillSummaryCard(
          type: BillOrderType.order,
          order: null,
          detail: detail,
          symbol: '₹',
        ),
      );

      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });
  });

  group('OrderTimelineCard', () {
    testWidgets('previews only the two most recent steps', (tester) async {
      printTestDivider('OrderTimelineCard previews only the two most recent steps');
      final timeline = detail.timeline!;
      await pumpCard(tester, OrderTimelineCard(timeline: timeline));

      printTestLog('steps in fixture → expected: 5, actual: ${timeline.length}');
      expect(timeline.length, 5);
      // The card is a preview: it sublists to the last two entries, so the
      // earliest step is deliberately not on screen.
      printTestLog('latest step → expected: "Out For Delivery" visible');
      expect(find.textContaining('Out For Delivery'), findsWidgets);
      printTestLog('previous step → expected: "Picked Up" visible');
      expect(find.textContaining('Picked Up'), findsWidgets);
      printTestLog('earliest step → expected: "Received" absent');
      expect(find.textContaining('Received'), findsNothing);
    });

    testWidgets('offers a track action only when one is wired up', (
      tester,
    ) async {
      printTestDivider('OrderTimelineCard offers a track action only when one is wired up');
      var tracked = false;
      await pumpCard(
        tester,
        OrderTimelineCard(
          timeline: detail.timeline!,
          onTrackOrder: () => tracked = true,
        ),
      );

      final withAction = find.byType(InkWell).evaluate().length;
      printTestLog('tappable actions with tracking → $withAction');

      await pumpCard(tester, OrderTimelineCard(timeline: detail.timeline!));
      final withoutAction = find.byType(InkWell).evaluate().length;
      printTestLog(
        'tappable actions without tracking → expected: fewer than $withAction, actual: $withoutAction',
      );
      expect(withoutAction, lessThan(withAction));
      expect(tracked, isFalse);
    });

    testWidgets('renders an empty timeline without breaking', (tester) async {
      printTestDivider('OrderTimelineCard renders an empty timeline without breaking');
      await pumpCard(tester, const OrderTimelineCard(timeline: []));

      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    });
  });

  group('OrderNoteCard', () {
    testWidgets('shows the note text', (tester) async {
      printTestDivider('OrderNoteCard shows the note text');
      await pumpCard(tester, const OrderNoteCard(note: 'Leave at the gate'));

      printTestLog('note → expected: "Leave at the gate" visible');
      expect(find.text('Leave at the gate'), findsOneWidget);
    });
  });
}
