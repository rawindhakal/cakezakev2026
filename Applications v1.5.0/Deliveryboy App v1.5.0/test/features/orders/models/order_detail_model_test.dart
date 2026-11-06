import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  late OrderDetail detail;

  setUp(() {
    // Mirrors the real /order_by_id response — refresh
    // test/fixtures/orders/order_detail.json when the backend contract
    // changes, instead of editing these tests.
    detail = OrderDetail.fromJson(
      jsonDecode(
            File('test/fixtures/orders/order_detail.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('parses the envelope and its four sections', () {
    printTestDivider('parses the envelope and its four sections');
    printTestLog('status → expected: 1, actual: ${detail.status}');
    expect(detail.status, 1);
    final data = detail.data!;
    printTestLog('order → expected: present, actual: ${data.order != null}');
    expect(data.order, isNotNull);
    printTestLog('orderItems → expected: 3, actual: ${data.orderItems?.length}');
    expect(data.orderItems?.length, 3);
    printTestLog('deliveryBoys → expected: non-empty, actual: ${data.deliveryBoys?.length}');
    expect(data.deliveryBoys, isNotEmpty);
    printTestLog('timeline → expected: 5, actual: ${data.timeline?.length}');
    expect(data.timeline?.length, 5);
  });

  test('parses the order block', () {
    printTestDivider('parses the order block');
    final order = detail.data!.order!;
    printTestLog('id → expected: 6, actual: ${order.id}');
    expect(order.id, 6);
    printTestLog('orderNumber → expected: "SB-ORD-00006", actual: "${order.orderNumber}"');
    expect(order.orderNumber, 'SB-ORD-00006');
    printTestLog('paymentMethod → expected: "Razorpay", actual: "${order.paymentMethod}"');
    expect(order.paymentMethod, 'Razorpay');
    printTestLog('finalTotal → expected: 246.3, actual: ${order.finalTotal}');
    expect(order.finalTotal, 246.3);
    printTestLog('otp → expected: 576400, actual: ${order.otp}');
    expect(order.otp, 576400);
    printTestLog('activeStatus → expected: 5, actual: ${order.activeStatus}');
    expect(order.activeStatus, 5);
  });

  test('exposes the current step through activeStatus, not an orderStatus field', () {
    printTestDivider('exposes the current step through activeStatus, not an orderStatus field');
    // Unlike OrderData from the list endpoint, the detail `Order` model has no
    // `orderStatus` field at all — the detail payload doesn't send one. The
    // current step comes from `active_status` plus `order_status_name`.
    final order = detail.data!.order!;
    printTestLog('activeStatus → expected: 5, actual: ${order.activeStatus}');
    expect(order.activeStatus, 5);
    printTestLog('orderStatusName → expected: "Out For Delivery", actual: "${order.orderStatusName}"');
    expect(order.orderStatusName, 'Out For Delivery');
  });

  test('parses the payment fields the collect-cash logic reads', () {
    printTestDivider('parses the payment fields the collect-cash logic reads');
    final order = detail.data!.order!;
    printTestLog('walletBalance → expected: 0.0, actual: ${order.walletBalance}');
    expect(order.walletBalance, 0.0);
    printTestLog('remainingFinal → expected: 246.3, actual: ${order.remainingFinal}');
    expect(order.remainingFinal, 246.3);
    printTestLog('refundAmount → expected: 0.0, actual: ${order.refundAmount}');
    expect(order.refundAmount, 0.0);
  });

  test('parses each line item', () {
    printTestDivider('parses each line item');
    final item = detail.data!.orderItems!.first;
    printTestLog('id → expected: 14, actual: ${item.id}');
    expect(item.id, 14);
    printTestLog('productName → expected: non-empty, actual: "${item.productName}"');
    expect(item.productName, isNotEmpty);
    printTestLog('quantity → expected: > 0, actual: ${item.quantity}');
    expect(item.quantity, greaterThan(0));
  });

  test('parses the timeline in the order the API returned it', () {
    printTestDivider('parses the timeline in the order the API returned it');
    final timeline = detail.data!.timeline!;
    printTestLog('first status → expected: 2, actual: ${timeline.first.status}');
    expect(timeline.first.status, 2);
    printTestLog('first statusName → expected: "Received", actual: "${timeline.first.statusName}"');
    expect(timeline.first.statusName, 'Received');
    printTestLog('first datetime → expected: "2026-08-11 05:45:51", actual: "${timeline.first.datetime}"');
    expect(timeline.first.datetime, '2026-08-11 05:45:51');
    printTestLog('last status → expected: > first, actual: ${timeline.last.status}');
    expect(timeline.last.status, greaterThan(timeline.first.status!));
  });

  test('parses a delivery boy, whose name is a per-language map', () {
    printTestDivider('parses a delivery boy, whose name is a per-language map');
    final boy = detail.data!.deliveryBoys!.first;
    printTestLog('id → expected: 33, actual: ${boy.id}');
    expect(boy.id, 33);
    // `name` is an object keyed by language code, not a plain string.
    printTestLog('name.en → expected: "Gohil Adityasinh", actual: "${boy.name?.en}"');
    expect(boy.name?.en, 'Gohil Adityasinh');
  });

  test('survives a response with no data block', () {
    printTestDivider('survives a response with no data block');
    final empty = OrderDetail.fromJson(const {'status': 1, 'message': 'ok'});
    printTestLog('data → expected: null, actual: ${empty.data}');
    expect(empty.data, isNull);
  });

  test('survives a data block with every section missing', () {
    printTestDivider('survives a data block with every section missing');
    final sparse = OrderDetailData.fromJson(const <String, dynamic>{});
    printTestLog('order → expected: null, actual: ${sparse.order}');
    expect(sparse.order, isNull);
    printTestLog('orderItems → expected: null, actual: ${sparse.orderItems}');
    expect(sparse.orderItems, isNull);
    printTestLog('timeline → expected: null, actual: ${sparse.timeline}');
    expect(sparse.timeline, isNull);
  });

  test('toJson round-trips the sections it carries', () {
    printTestDivider('toJson round-trips the sections it carries');
    final original = detail.data!;
    final roundTripped = OrderDetailData.fromJson(original.toJson());

    printTestLog('order number → expected: "${original.order?.orderNumber}", actual: "${roundTripped.order?.orderNumber}"');
    expect(roundTripped.order?.orderNumber, original.order?.orderNumber);
    printTestLog('items → expected: ${original.orderItems?.length}, actual: ${roundTripped.orderItems?.length}');
    expect(roundTripped.orderItems?.length, original.orderItems?.length);
    printTestLog('timeline → expected: ${original.timeline?.length}, actual: ${roundTripped.timeline?.length}');
    expect(roundTripped.timeline?.length, original.timeline?.length);
  });
}
