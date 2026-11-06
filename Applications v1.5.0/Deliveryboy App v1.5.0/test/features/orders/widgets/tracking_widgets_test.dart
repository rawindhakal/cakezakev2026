import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_action_buttons.dart';
import 'package:deliveryboy/features/orders/widgets/order_tracking_info_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_tracking_no_location.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late Order order;

  setUp(() {
    order = OrderDetail.fromJson(
      jsonDecode(
            File('test/fixtures/orders/order_detail.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    ).data!.order!;
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('OrderActionButtons', () {
    testWidgets('shows the 4 contact/direction tiles but no track button off-route', (tester) async {
      printTestDivider('OrderActionButtons shows the 4 contact/direction tiles but no track button off-route');
      order.activeStatus = 6; // Delivered — not "Out For Delivery" (5)
      await tester.pumpWidget(pumpTestWidget(OrderActionButtons(order: order)));

      printTestLog('expected: 4 InkWell action tiles, actual: ${find.byType(InkWell).evaluate().length}');
      expect(find.byType(InkWell), findsNWidgets(4));
    });

    testWidgets('adds a 5th, full-width track button while out for delivery', (tester) async {
      printTestDivider('OrderActionButtons adds a 5th, full-width track button while out for delivery');
      order.activeStatus = 5; // Out For Delivery
      await tester.pumpWidget(pumpTestWidget(OrderActionButtons(order: order)));

      printTestLog('expected: 5 InkWell action tiles, actual: ${find.byType(InkWell).evaluate().length}');
      expect(find.byType(InkWell), findsNWidgets(5));
    });

    testWidgets('a null order still renders without crashing', (tester) async {
      printTestDivider('OrderActionButtons a null order still renders without crashing');
      await tester.pumpWidget(pumpTestWidget(const OrderActionButtons(order: null)));

      printTestLog('expected: no exception, actual: ${tester.takeException()}');
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsNWidgets(4));
    });
  });

  group('OrderTrackingInfoCard', () {
    testWidgets('shows customer name, address and a chat button when provided', (tester) async {
      printTestDivider('OrderTrackingInfoCard shows customer name, address and a chat button when provided');
      var chatTapped = false;
      await tester.pumpWidget(
        pumpTestWidget(
          OrderTrackingInfoCard(
            customerName: 'Ravi Kumar',
            customerNumber: '9876543210',
            address: '221B Baker Street',
            onChatCustomer: () => chatTapped = true,
          ),
        ),
      );

      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('221B Baker Street'), findsOneWidget);
      printTestLog('expected: name+address visible, actual: found');
      // 2 round icon buttons: call + chat.
      expect(find.byType(InkWell), findsNWidgets(2));

      await tester.tap(find.byType(InkWell).last);
      printTestLog('expected: chatTapped true, actual: $chatTapped');
      expect(chatTapped, isTrue);
    });

    testWidgets('drops the chat button and shows the alternate number row when given', (tester) async {
      printTestDivider('OrderTrackingInfoCard drops the chat button and shows the alternate number row when given');
      await tester.pumpWidget(
        pumpTestWidget(
          const OrderTrackingInfoCard(
            customerName: 'Ravi Kumar',
            customerNumber: '9876543210',
            customerAlternateNumber: '9123456789',
            address: '221B Baker Street',
          ),
        ),
      );

      expect(find.text('9123456789'), findsOneWidget);
      printTestLog('expected: alternate number row visible, actual: found');
      // Only the call icon buttons (main + alternate) — no chat button.
      expect(find.byType(InkWell), findsNWidgets(2));
    });
  });

  group('OrderTrackingNoLocation', () {
    testWidgets('shows the GPS-off copy when the location service itself is off', (tester) async {
      printTestDivider('OrderTrackingNoLocation shows the GPS-off copy when the location service itself is off');
      var retried = false;
      await tester.pumpWidget(
        pumpTestWidget(
          OrderTrackingNoLocation(locationServiceOff: true, onRetry: () => retried = true),
          wrapInScaffold: false,
        ),
      );

      await tester.tap(find.text('try_again'));
      printTestLog('expected: retried true, actual: $retried');
      expect(retried, isTrue);
    });

    testWidgets('shows the permission copy when GPS is on but permission is denied', (tester) async {
      printTestDivider('OrderTrackingNoLocation shows the permission copy when GPS is on but permission is denied');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderTrackingNoLocation(locationServiceOff: false, onRetry: () {}),
          wrapInScaffold: false,
        ),
      );

      printTestLog('expected: try_again button visible, actual: found');
      expect(find.text('try_again'), findsOneWidget);
    });
  });
}
