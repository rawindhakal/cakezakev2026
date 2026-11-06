import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  late Map<String, dynamic> listResponse;
  late ReturnDetailResponse detail;
  late List<ReturnRequestData> requests;

  Map<String, dynamic> readFixture(String name) =>
      jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  setUp(() {
    // Mirrors the real return-orders list and detail responses — refresh the
    // fixtures when the backend contract changes, instead of editing these
    // tests.
    listResponse = readFixture('return_orders_list');
    detail = ReturnDetailResponse.fromJson(readFixture('return_order_detail'));
    requests = (listResponse['data'] as List)
        .map(
          (e) => ReturnRequestData.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  ReturnRequestData byId(int id) => requests.firstWhere((r) => r.id == id);

  test('parses every request in the page', () {
    printTestDivider('parses every request in the page');
    printTestLog('count → expected: 8, actual: ${requests.length}');
    expect(requests.length, 8);
    printTestLog('total → expected: 8, actual: ${listResponse['total']}');
    expect(listResponse['total'], 8);
  });

  test('parses a completed return request', () {
    printTestDivider('parses a completed return request');
    final request = byId(23);
    printTestLog('returnNumber → expected: "RET-00023", actual: "${request.returnNumber}"');
    expect(request.returnNumber, 'RET-00023');
    printTestLog('orderId → expected: 195, actual: ${request.orderId}');
    expect(request.orderId, 195);
    printTestLog('orderItemId → expected: 291, actual: ${request.orderItemId}');
    expect(request.orderItemId, 291);
    printTestLog('status → expected: 8, actual: ${request.status}');
    expect(request.status, 8);
    printTestLog('orderStatusName → expected: "Refund Completed", actual: "${request.orderStatusName}"');
    expect(request.orderStatusName, 'Refund Completed');
    printTestLog('returnReason → expected: "no need this item", actual: "${request.returnReason}"');
    expect(request.returnReason, 'no need this item');
    printTestLog('customerName → expected: "hency", actual: "${request.customerName}"');
    expect(request.customerName, 'hency');
  });

  test('parses the product and money fields', () {
    printTestDivider('parses the product and money fields');
    final request = byId(23);
    printTestLog('productName → expected: "Green Kiwi 2 kg", actual: "${request.productName}"');
    expect(request.productName, 'Green Kiwi 2 kg');
    printTestLog('quantity → expected: 1, actual: ${request.quantity}');
    expect(request.quantity, 1);
    printTestLog('price → expected: 250.0, actual: ${request.price}');
    expect(request.price, 250.0);
    printTestLog('bonus → expected: 0.0, actual: ${request.deliveryBoyBonusAmount}');
    expect(request.deliveryBoyBonusAmount, 0.0);
  });

  test('reads the status name from order_status_name, not status_name', () {
    printTestDivider('reads the status name from order_status_name, not status_name');
    // The payload's own `status_name` is null on every row; the human-readable
    // label lives in `order_status_name`.
    final raw = (listResponse['data'] as List).first as Map;
    printTestLog('payload status_name → expected: null, actual: ${raw['status_name']}');
    expect(raw['status_name'], isNull);
    printTestLog('model orderStatusName → expected: non-empty, actual: "${byId(23).orderStatusName}"');
    expect(byId(23).orderStatusName, isNotEmpty);
  });

  test('parses the pickup address and the customer address separately', () {
    printTestDivider('parses the pickup address and the customer address separately');
    final request = byId(23);
    printTestLog('address → expected: present, actual: ${request.address != null}');
    expect(request.address, isNotNull);
    printTestLog('address name → expected: "hency", actual: "${request.address?.name}"');
    expect(request.address?.name, 'hency');
    printTestLog('pickupAddress → expected: present, actual: ${request.pickupAddress != null}');
    expect(request.pickupAddress, isNotNull);
  });

  test('parses the returned item block', () {
    printTestDivider('parses the returned item block');
    final request = byId(23);
    printTestLog('returnItem → expected: present, actual: ${request.returnItem != null}');
    expect(request.returnItem, isNotNull);
  });

  test('parses the timeline', () {
    printTestDivider('parses the timeline');
    final request = byId(23);
    printTestLog('timeline → expected: 7 entries, actual: ${request.timeline?.length}');
    expect(request.timeline?.length, 7);
  });

  test('parses a request still awaiting pickup', () {
    printTestDivider('parses a request still awaiting pickup');
    // Status 5 is the step where the rider still has work to do.
    final request = byId(9);
    printTestLog('status → expected: 5, actual: ${request.status}');
    expect(request.status, 5);
    printTestLog('orderStatusName → expected: "Out for Pickup", actual: "${request.orderStatusName}"');
    expect(request.orderStatusName, 'Out for Pickup');
    printTestLog('timeline → expected: 1 entry, actual: ${request.timeline?.length}');
    expect(request.timeline?.length, 1);
  });

  test('leaves optional remarks and reject reason null when unset', () {
    printTestDivider('leaves optional remarks and reject reason null when unset');
    final request = byId(23);
    printTestLog('remarks → expected: null, actual: ${request.remarks}');
    expect(request.remarks, isNull);
    printTestLog('rejectReason → expected: null, actual: ${request.rejectReason}');
    expect(request.rejectReason, isNull);
  });

  test('parses the detail response', () {
    printTestDivider('parses the detail response');
    printTestLog('status → expected: 1, actual: ${detail.status}');
    expect(detail.status, 1);
    final data = detail.data!;
    printTestLog('returnNumber → expected: non-empty, actual: "${data.returnNumber}"');
    expect(data.returnNumber, isNotEmpty);
    printTestLog('productName → expected: non-empty, actual: "${data.productName}"');
    expect(data.productName, isNotEmpty);
    printTestLog('timeline → expected: non-empty, actual: ${data.timeline?.length}');
    expect(data.timeline, isNotEmpty);
  });

  test('parses the returned item add-ons', () {
    printTestDivider('parses the returned item add-ons');
    final item = detail.data!.returnItem!;
    printTestLog('addons → expected: 2, actual: ${item.addons?.length}');
    expect(item.addons?.length, 2);
    printTestLog('addonTotal → expected: 80.0, actual: ${item.addonTotal}');
    expect(item.addonTotal, 80.0);
    final paid = item.addons![1];
    printTestLog('optionName → expected: "Rumali roti 2 pieces", actual: "${paid.optionName}"');
    expect(paid.optionName, 'Rumali roti 2 pieces');
    expect(paid.qty, 2);
    expect(paid.linePrice, 80.0);
    expect(item.addons!.first.isFree, 1);
  });

  test('leaves add-ons empty on items without them', () {
    printTestDivider('leaves add-ons empty on items without them');
    final item = byId(23).returnItem!;
    printTestLog('addons → expected: [], actual: ${item.addons}');
    expect(item.addons, isEmpty);
  });

  test('survives a request object with nothing in it', () {
    printTestDivider('survives a request object with nothing in it');
    final request = ReturnRequestData.fromJson(const <String, dynamic>{});
    printTestLog('id → expected: null, actual: ${request.id}');
    expect(request.id, isNull);
    printTestLog('address → expected: null, actual: ${request.address}');
    expect(request.address, isNull);
    printTestLog('returnItem → expected: null, actual: ${request.returnItem}');
    expect(request.returnItem, isNull);
    printTestLog('price → expected: 0.0, actual: ${request.price}');
    expect(request.price, 0.0);
  });

  test('survives a detail response with no data block', () {
    printTestDivider('survives a detail response with no data block');
    final empty = ReturnDetailResponse.fromJson(const {
      'status': 1,
      'message': 'ok',
    });
    printTestLog('data → expected: null, actual: ${empty.data}');
    expect(empty.data, isNull);
  });

  test('PaginatedResponse.fromJson reads the whole page', () {
    printTestDivider('PaginatedResponse.fromJson reads the whole page');
    final page = PaginatedResponse<ReturnRequestData>.fromJson(
      listResponse,
      ReturnRequestData.fromJson,
    );
    printTestLog('data length → expected: 8, actual: ${page.data.length}');
    expect(page.data.length, 8);
    printTestLog('total → expected: 8, actual: ${page.total}');
    expect(page.total, 8);
  });

  test('toJson round-trips the fields the app relies on', () {
    printTestDivider('toJson round-trips the fields the app relies on');
    final original = byId(23);
    final roundTripped = ReturnRequestData.fromJson(original.toJson());

    printTestLog('returnNumber → expected: "${original.returnNumber}", actual: "${roundTripped.returnNumber}"');
    expect(roundTripped.returnNumber, original.returnNumber);
    printTestLog('status → expected: ${original.status}, actual: ${roundTripped.status}');
    expect(roundTripped.status, original.status);
    printTestLog('price → expected: ${original.price}, actual: ${roundTripped.price}');
    expect(roundTripped.price, original.price);
    printTestLog('timeline → expected: ${original.timeline?.length}, actual: ${roundTripped.timeline?.length}');
    expect(roundTripped.timeline?.length, original.timeline?.length);
  });
}
