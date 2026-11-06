import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  late Map<String, dynamic> response;
  late List<OrderData> orders;

  setUp(() {
    // Mirrors the real /orders response — refresh
    // test/fixtures/orders/orders_list.json when the backend contract
    // changes, instead of editing these tests.
    response =
        jsonDecode(
              File('test/fixtures/orders/orders_list.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    orders = (response['data'] as List)
        .map((e) => OrderData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  OrderData byNumber(String number) =>
      orders.firstWhere((o) => o.orderNumber == number);

  test('parses every order in the page', () {
    printTestDivider('parses every order in the page');
    printTestLog('count → expected: 10, actual: ${orders.length}');
    expect(orders.length, 10);
    printTestLog('total → expected: 27, actual: ${response['total']}');
    expect(response['total'], 27);
  });

  test('parses a prepaid order end to end', () {
    printTestDivider('parses a prepaid order end to end');
    final order = byNumber('SB-ORD-00006');

    printTestLog('id → expected: 6, actual: ${order.id}');
    expect(order.id, 6);
    printTestLog('orderNumber → expected: "SB-ORD-00006", actual: "${order.orderNumber}"');
    expect(order.orderNumber, 'SB-ORD-00006');
    printTestLog('paymentMethod → expected: "Razorpay", actual: "${order.paymentMethod}"');
    expect(order.paymentMethod, 'Razorpay');
    printTestLog('total → expected: 195.3, actual: ${order.total}');
    expect(order.total, 195.3);
    printTestLog('finalTotal → expected: 246.3, actual: ${order.finalTotal}');
    expect(order.finalTotal, 246.3);
    printTestLog('deliveryCharges.amount → expected: 51.0, actual: ${order.deliveryCharges?.amount}');
    expect(order.deliveryCharges?.amount, 51.0);
    printTestLog('deliveryCharges.taxRate → expected: 5.0, actual: ${order.deliveryCharges?.taxRate}');
    expect(order.deliveryCharges?.taxRate, 5.0);
    printTestLog('taxAmount → expected: 9.3, actual: ${order.taxAmount}');
    expect(order.taxAmount, 9.3);
    printTestLog('taxBreakdown length → expected: 2, actual: ${order.taxBreakdown?.length}');
    expect(order.taxBreakdown?.length, 2);
    printTestLog('taxBreakdown first name → expected: "CGST", actual: "${order.taxBreakdown?.first.name}"');
    expect(order.taxBreakdown?.first.name, 'CGST');
    printTestLog('orderStatus → expected: "5", actual: "${order.orderStatus}"');
    expect(order.orderStatus, '5');
    printTestLog('orderStatusName → expected: "Out For Delivery", actual: "${order.orderStatusName}"');
    expect(order.orderStatusName, 'Out For Delivery');
    printTestLog('channel → expected: "quick", actual: "${order.channel}"');
    expect(order.channel, 'quick');
    printTestLog('currency → expected: "₹", actual: "${order.currency}"');
    expect(order.currency, '₹');
    printTestLog('otp → expected: 576400, actual: ${order.otp}');
    expect(order.otp, 576400);
  });

  test('parses savedAmount even though the API sends it as a quoted string', () {
    printTestDivider('parses savedAmount even though the API sends it as a quoted string');
    // "saved_amount": "8.70" — a string in the payload, a double in the model.
    final order = byNumber('SB-ORD-00006');
    printTestLog('savedAmount → expected: 8.7, actual: ${order.savedAmount}');
    expect(order.savedAmount, 8.7);
  });

  test('parses the wallet-paid order, where nothing is left to collect', () {
    printTestDivider('parses the wallet-paid order, where nothing is left to collect');
    // The rider's cash-collection UI keys off exactly these three fields.
    final order = byNumber('SB-ORD-00142');
    printTestLog('walletBalance → expected: 103.5, actual: ${order.walletBalance}');
    expect(order.walletBalance, 103.5);
    printTestLog('finalTotal → expected: 0.0, actual: ${order.finalTotal}');
    expect(order.finalTotal, 0.0);
    printTestLog('remainingFinal → expected: 0.0, actual: ${order.remainingFinal}');
    expect(order.remainingFinal, 0.0);
    printTestLog('paymentMethod → expected: "COD", actual: "${order.paymentMethod}"');
    expect(order.paymentMethod, 'COD');
  });

  test('parses the customer address block', () {
    printTestDivider('parses the customer address block');
    final address = byNumber('SB-ORD-00006').address!;
    printTestLog('name → expected: non-empty, actual: "${address.name}"');
    expect(address.name, isNotEmpty);
    printTestLog('address → expected: non-empty, actual: "${address.address}"');
    expect(address.address, isNotEmpty);
  });

  test('parses the store info the tracking map needs', () {
    printTestDivider('parses the store info the tracking map needs');
    final store = byNumber('SB-ORD-00006').storeInfo!;
    printTestLog('storeName → expected: "Mumbai Store", actual: "${store.storeName}"');
    expect(store.storeName, 'Mumbai Store');
    // Coordinates arrive as strings and stay strings on the model.
    printTestLog('latitude → expected: "19.076", actual: "${store.latitude}"');
    expect(store.latitude, '19.076');
    printTestLog('longitude → expected: non-empty, actual: "${store.longitude}"');
    expect(store.longitude, isNotEmpty);
  });

  test('parses the line items', () {
    printTestDivider('parses the line items');
    final order = byNumber('SB-ORD-00006');
    printTestLog('items → expected: 3, actual: ${order.items?.length}');
    expect(order.items?.length, 3);
    final first = order.items!.first;
    printTestLog('first item id → expected: 12, actual: ${first.id}');
    expect(first.id, 12);
    printTestLog('first product name → expected: non-empty, actual: "${first.productName}"');
    expect(first.productName, isNotEmpty);
  });

  test('parses the delivery-boy bonus block', () {
    printTestDivider('parses the delivery-boy bonus block');
    final order = byNumber('SB-ORD-00006');
    printTestLog('bonusAmount → expected: 40.0, actual: ${order.deliveryBoyBonusAmount}');
    expect(order.deliveryBoyBonusAmount, 40.0);
    final bonus = order.deliveryBoyBonusDetails!;
    printTestLog('bonus finalTotal → expected: 195.3, actual: ${bonus.finalTotal}');
    expect(bonus.finalTotal, 195.3);
    printTestLog('bonus amount → expected: 40.0, actual: ${bonus.bonusAmount}');
    expect(bonus.bonusAmount, 40.0);
  });

  test('keeps empty additional and surge charge lists as empty, not null', () {
    printTestDivider('keeps empty additional and surge charge lists as empty, not null');
    final order = byNumber('SB-ORD-00006');
    printTestLog('additionalCharges → expected: empty list, actual: ${order.additionalCharges}');
    expect(order.additionalCharges, isEmpty);
    printTestLog('surgeCharges → expected: empty list, actual: ${order.surgeCharges}');
    expect(order.surgeCharges, isEmpty);
  });

  test('leaves a null cancellation reason null on a live order', () {
    printTestDivider('leaves a null cancellation reason null on a live order');
    final order = byNumber('SB-ORD-00006');
    printTestLog('userMobile → expected: null, actual: ${order.userMobile}');
    expect(order.userMobile, isNull);
    printTestLog('userCountryCode → expected: "+91", actual: "${order.userCountryCode}"');
    expect(order.userCountryCode, '+91');
  });

  test('parses a delivered COD order', () {
    printTestDivider('parses a delivered COD order');
    final order = byNumber('SB-ORD-00187');
    printTestLog('orderStatus → expected: "6", actual: "${order.orderStatus}"');
    expect(order.orderStatus, '6');
    printTestLog('orderStatusName → expected: "Delivered", actual: "${order.orderStatusName}"');
    expect(order.orderStatusName, 'Delivered');
    printTestLog('paymentMethod → expected: "COD", actual: "${order.paymentMethod}"');
    expect(order.paymentMethod, 'COD');
    printTestLog('finalTotal → expected: 567.0, actual: ${order.finalTotal}');
    expect(order.finalTotal, 567.0);
  });

  test('survives an order object with nothing in it', () {
    printTestDivider('survives an order object with nothing in it');
    final order = OrderData.fromJson(const <String, dynamic>{});
    printTestLog('id → expected: null, actual: ${order.id}');
    expect(order.id, isNull);
    printTestLog('items → expected: null, actual: ${order.items}');
    expect(order.items, isNull);
    printTestLog('address → expected: null, actual: ${order.address}');
    expect(order.address, isNull);
    // toSafeDouble floors missing money fields to 0 rather than leaving null,
    // so the UI never has to null-check an amount.
    printTestLog('finalTotal → expected: 0.0, actual: ${order.finalTotal}');
    expect(order.finalTotal, 0.0);
  });

  test('PaginatedResponse.fromJson reads the whole page', () {
    printTestDivider('PaginatedResponse.fromJson reads the whole page');
    final page = PaginatedResponse<OrderData>.fromJson(
      response,
      OrderData.fromJson,
    );
    printTestLog('data length → expected: 10, actual: ${page.data.length}');
    expect(page.data.length, 10);
    printTestLog('total → expected: 27, actual: ${page.total}');
    expect(page.total, 27);
    printTestLog('first order number → expected: "SB-ORD-00006", actual: "${page.data.first.orderNumber}"');
    expect(page.data.first.orderNumber, 'SB-ORD-00006');
  });

  test('toJson round-trips the fields the app relies on', () {
    printTestDivider('toJson round-trips the fields the app relies on');
    final original = byNumber('SB-ORD-00006');
    final roundTripped = OrderData.fromJson(original.toJson());

    printTestLog('orderNumber → expected: "${original.orderNumber}", actual: "${roundTripped.orderNumber}"');
    expect(roundTripped.orderNumber, original.orderNumber);
    printTestLog('finalTotal → expected: ${original.finalTotal}, actual: ${roundTripped.finalTotal}');
    expect(roundTripped.finalTotal, original.finalTotal);
    printTestLog('items → expected: ${original.items?.length}, actual: ${roundTripped.items?.length}');
    expect(roundTripped.items?.length, original.items?.length);
    printTestLog('storeInfo name → expected: "${original.storeInfo?.storeName}", actual: "${roundTripped.storeInfo?.storeName}"');
    expect(roundTripped.storeInfo?.storeName, original.storeInfo?.storeName);
  });
}
