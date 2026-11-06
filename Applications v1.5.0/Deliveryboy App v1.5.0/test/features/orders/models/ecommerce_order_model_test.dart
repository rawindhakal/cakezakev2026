import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  late Map<String, dynamic> listResponse;
  late Map<String, dynamic> detailResponse;
  late List<EcommerceOrderDataModel> items;

  Map<String, dynamic> readFixture(String name) =>
      jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  setUp(() {
    // Mirrors the real /ecom_orders and its detail response — refresh the
    // fixtures when the backend contract changes, instead of editing these
    // tests.
    listResponse = readFixture('ecommerce_orders_list');
    detailResponse = readFixture('ecommerce_order_detail');
    items = (listResponse['data'] as List)
        .map(
          (e) => EcommerceOrderDataModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('parses every row in the page', () {
    printTestDivider('parses every row in the page');
    printTestLog('count → expected: 5, actual: ${items.length}');
    expect(items.length, 5);
    printTestLog('total → expected: 5, actual: ${listResponse['total']}');
    expect(listResponse['total'], 5);
  });

  test('parses a row as one order *item*, not a whole order', () {
    printTestDivider('parses a row as one order *item*, not a whole order');
    // The ecommerce list is per order-item: `id` is the item id and `orderId`
    // is the order it belongs to, so a rider can have several rows from one
    // order.
    final item = items.first;
    printTestLog('id → expected: 413, actual: ${item.id}');
    expect(item.id, 413);
    printTestLog('orderId → expected: 170, actual: ${item.orderId}');
    expect(item.orderId, 170);
    printTestLog('productName → expected: non-empty, actual: "${item.productName}"');
    expect(item.productName, isNotEmpty);
    printTestLog('quantity → expected: 1, actual: ${item.quantity}');
    expect(item.quantity, 1);
  });

  test('parses the money fields', () {
    printTestDivider('parses the money fields');
    final item = items.first;
    printTestLog('price → expected: 822.0, actual: ${item.price}');
    expect(item.price, 822.0);
    printTestLog('subTotal → expected: 232.05, actual: ${item.subTotal}');
    expect(item.subTotal, 232.05);
    printTestLog('finalTotal → expected: 272.05, actual: ${item.finalTotal}');
    expect(item.finalTotal, 272.05);
    printTestLog('walletBalance → expected: 0.0, actual: ${item.walletBalance}');
    expect(item.walletBalance, 0.0);
    printTestLog('bonus → expected: 40.0, actual: ${item.deliveryBoyBonusAmount}');
    expect(item.deliveryBoyBonusAmount, 40.0);
  });

  test('parses the delivery status and payment method', () {
    printTestDivider('parses the delivery status and payment method');
    final item = items.first;
    printTestLog('activeStatus → expected: 6, actual: ${item.activeStatus}');
    expect(item.activeStatus, 6);
    printTestLog('paymentMethod → expected: "COD", actual: "${item.paymentMethod}"');
    expect(item.paymentMethod, 'COD');
    printTestLog('otp → expected: 686057, actual: ${item.otp}');
    expect(item.otp, 686057);
  });

  test('leaves channel null — this endpoint does not send one', () {
    printTestDivider('leaves channel null — this endpoint does not send one');
    // The quick-orders payload carries `channel: "quick"`; the ecommerce one
    // omits it entirely, so anything branching on channel must not assume it.
    final item = items.first;
    printTestLog('channel → expected: null, actual: ${item.channel}');
    expect(item.channel, isNull);
  });

  test('parses the customer address block', () {
    printTestDivider('parses the customer address block');
    final item = items.first;
    printTestLog('addressInfo → expected: present, actual: ${item.addressInfo != null}');
    expect(item.addressInfo, isNotNull);
    printTestLog('address name → expected: non-empty, actual: "${item.addressInfo?.name}"');
    expect(item.addressInfo?.name, isNotEmpty);
  });

  test('parses the detail response, which returns a single-row list', () {
    printTestDivider('parses the detail response, which returns a single-row list');
    // Unlike the quick-order detail (an object), this endpoint answers with a
    // one-element list.
    final data = detailResponse['data'] as List;
    printTestLog('data length → expected: 1, actual: ${data.length}');
    expect(data.length, 1);

    final item = EcommerceOrderDataModel.fromJson(
      Map<String, dynamic>.from(data.first as Map),
    );
    printTestLog('id → expected: non-null, actual: ${item.id}');
    expect(item.id, isNotNull);
    printTestLog('productName → expected: non-empty, actual: "${item.productName}"');
    expect(item.productName, isNotEmpty);
  });

  test('survives an item object with nothing in it', () {
    printTestDivider('survives an item object with nothing in it');
    final item = EcommerceOrderDataModel.fromJson(const <String, dynamic>{});
    printTestLog('id → expected: null, actual: ${item.id}');
    expect(item.id, isNull);
    printTestLog('addressInfo → expected: null, actual: ${item.addressInfo}');
    expect(item.addressInfo, isNull);
    // Money fields floor to 0 rather than staying null.
    printTestLog('finalTotal → expected: 0.0, actual: ${item.finalTotal}');
    expect(item.finalTotal, 0.0);
  });

  test('ignores an address sent as something other than an object', () {
    printTestDivider('ignores an address sent as something other than an object');
    // fromJson type-checks `address` before parsing it, so a scalar there
    // leaves addressInfo null instead of throwing.
    final item = EcommerceOrderDataModel.fromJson(const {'address': 'N/A'});
    printTestLog('addressInfo → expected: null, actual: ${item.addressInfo}');
    expect(item.addressInfo, isNull);
  });

  test('PaginatedResponse.fromJson reads the whole page', () {
    printTestDivider('PaginatedResponse.fromJson reads the whole page');
    final page = PaginatedResponse<EcommerceOrderDataModel>.fromJson(
      listResponse,
      EcommerceOrderDataModel.fromJson,
    );
    printTestLog('data length → expected: 5, actual: ${page.data.length}');
    expect(page.data.length, 5);
    printTestLog('total → expected: 5, actual: ${page.total}');
    expect(page.total, 5);
  });

  test('toJson round-trips the fields the app relies on', () {
    printTestDivider('toJson round-trips the fields the app relies on');
    final original = items.first;
    final roundTripped = EcommerceOrderDataModel.fromJson(original.toJson());

    printTestLog('id → expected: ${original.id}, actual: ${roundTripped.id}');
    expect(roundTripped.id, original.id);
    printTestLog('orderId → expected: ${original.orderId}, actual: ${roundTripped.orderId}');
    expect(roundTripped.orderId, original.orderId);
    printTestLog('finalTotal → expected: ${original.finalTotal}, actual: ${roundTripped.finalTotal}');
    expect(roundTripped.finalTotal, original.finalTotal);
    printTestLog('productName → expected: "${original.productName}", actual: "${roundTripped.productName}"');
    expect(roundTripped.productName, original.productName);
  });
}
