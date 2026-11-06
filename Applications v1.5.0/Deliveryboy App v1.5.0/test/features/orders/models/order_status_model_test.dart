import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  OrderStatus readFixture(String name) => OrderStatus.fromJson(
    jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('parses the quick-order statuses in the order the API returned them', () {
    printTestDivider('parses the quick-order statuses in the order the API returned them');
    final statuses = readFixture('order_statuses');

    final ids = statuses.data!.map((s) => s.id).toList();
    printTestLog('ids → expected: [10, 11, 5, 6], actual: $ids');
    expect(ids, ['10', '11', '5', '6']);
    // The list is the rider's forward path, not sorted by id.
    final names = statuses.data!.map((s) => s.status).toList();
    printTestLog('names → expected: pickup → delivered, actual: $names');
    expect(names, [
      'Ready for Pickup',
      'Picked Up',
      'Out For Delivery',
      'Delivered',
    ]);
  });

  test('parses ids as strings even though the API sends them as ints', () {
    printTestDivider('parses ids as strings even though the API sends them as ints');
    // The payload has `"id": 10`; the model normalises to "10" so it can be
    // compared against the string status the list endpoints expect.
    final first = readFixture('order_statuses').data!.first;
    printTestLog('id → expected: "10" (String), actual: ${first.id} (${first.id.runtimeType})');
    expect(first.id, '10');
    expect(first.id, isA<String>());
  });

  test('parses the return statuses alongside the order ones', () {
    printTestDivider('parses the return statuses alongside the order ones');
    final statuses = readFixture('order_statuses');

    final ids = statuses.returnStatuses!.map((s) => s.id).toList();
    printTestLog('return ids → expected: [5, 6, 7], actual: $ids');
    expect(ids, ['5', '6', '7']);
    printTestLog(
      'first return status → expected: "Out for Pickup", actual: "${statuses.returnStatuses!.first.status}"',
    );
    expect(statuses.returnStatuses!.first.status, 'Out for Pickup');
  });

  test('the ecommerce channel offers a shorter path than quick orders', () {
    printTestDivider('the ecommerce channel offers a shorter path than quick orders');
    // Ecommerce riders never see the store-pickup steps (10/11).
    final ecommerce = readFixture('ecommerce_order_statuses');

    final ids = ecommerce.data!.map((s) => s.id).toList();
    printTestLog('ecommerce ids → expected: [5, 6], actual: $ids');
    expect(ids, ['5', '6']);
    // Return statuses come back the same on either channel.
    printTestLog(
      'return ids → expected: [5, 6, 7], actual: ${ecommerce.returnStatuses!.map((s) => s.id).toList()}',
    );
    expect(ecommerce.returnStatuses!.map((s) => s.id).toList(), ['5', '6', '7']);
  });

  test('defaults isDisabled to "0" when the API omits it', () {
    printTestDivider('defaults isDisabled to "0" when the API omits it');
    final first = readFixture('order_statuses').data!.first;
    printTestLog('isDisabled → expected: "0", actual: "${first.isDisabled}"');
    expect(first.isDisabled, '0');
  });

  test('survives a response with neither list', () {
    printTestDivider('survives a response with neither list');
    final empty = OrderStatus.fromJson(const {'status': 1, 'message': 'ok'});
    printTestLog('data → expected: null, actual: ${empty.data}');
    expect(empty.data, isNull);
    printTestLog('returnStatuses → expected: null, actual: ${empty.returnStatuses}');
    expect(empty.returnStatuses, isNull);
  });

  test('survives a status entry with nothing in it', () {
    printTestDivider('survives a status entry with nothing in it');
    final status = OrderStatusData.fromJson(const <String, dynamic>{});
    printTestLog('id → expected: null, actual: ${status.id}');
    expect(status.id, isNull);
    printTestLog('status → expected: null, actual: ${status.status}');
    expect(status.status, isNull);
    printTestLog('isDisabled → expected: "0", actual: "${status.isDisabled}"');
    expect(status.isDisabled, '0');
  });

  test('toJson round-trips both lists', () {
    printTestDivider('toJson round-trips both lists');
    final original = readFixture('order_statuses');
    final roundTripped = OrderStatus.fromJson(original.toJson());

    printTestLog(
      'data → expected: ${original.data!.length}, actual: ${roundTripped.data!.length}',
    );
    expect(roundTripped.data!.length, original.data!.length);
    printTestLog(
      'return statuses → expected: ${original.returnStatuses!.length}, actual: ${roundTripped.returnStatuses!.length}',
    );
    expect(roundTripped.returnStatuses!.length, original.returnStatuses!.length);
    printTestLog(
      'first id → expected: "${original.data!.first.id}", actual: "${roundTripped.data!.first.id}"',
    );
    expect(roundTripped.data!.first.id, original.data!.first.id);
  });
}
