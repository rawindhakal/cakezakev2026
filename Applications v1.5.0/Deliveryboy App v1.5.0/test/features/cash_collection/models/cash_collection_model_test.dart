import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/cash_collection/cash_collections_list.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('CashCollectionData.fromJson', () {
    test('parses the real payload: transactions, cash in hand, collected', () {
      printTestDivider(
        'CashCollectionData.fromJson parses the real payload: transactions, cash in hand, collected',
      );
      final data = CashCollectionData.fromJson(
        fixture()['data'] as Map<String, dynamic>,
      );

      printTestLog(
        'transactions length → expected: 3, actual: ${data.cashCollections?.length}',
      );
      expect(data.cashCollections?.length, 3);
      printTestLog(
        'cashInHand → expected: "1245.50", actual: ${data.cashInHand}',
      );
      expect(data.cashInHand, '1245.50');
      printTestLog(
        'cashCollected → expected: "8420.75", actual: ${data.cashCollected}',
      );
      expect(data.cashCollected, '8420.75');
    });

    test('missing transactions key becomes an empty list, not null', () {
      printTestDivider(
        'CashCollectionData.fromJson missing transactions key becomes an empty list, not null',
      );
      final data = CashCollectionData.fromJson({
        'cash_in_hand': null,
        'cash_collected': null,
      });

      printTestLog(
        'cashCollections → expected: [], actual: ${data.cashCollections}',
      );
      expect(data.cashCollections, isEmpty);
      printTestLog('cashInHand → expected: null, actual: ${data.cashInHand}');
      expect(data.cashInHand, isNull);
    });

    test('cash_in_hand/cash_collected pass through numeric values untouched', () {
      printTestDivider(
        'CashCollectionData.fromJson cash_in_hand/cash_collected pass through numeric values untouched',
      );
      final data = CashCollectionData.fromJson({
        'cash_in_hand': 1245.5,
        'cash_collected': 8420,
      });

      printTestLog('cashInHand → expected: 1245.5, actual: ${data.cashInHand}');
      expect(data.cashInHand, 1245.5);
      printTestLog(
        'cashCollected → expected: 8420, actual: ${data.cashCollected}',
      );
      expect(data.cashCollected, 8420);
    });
  });

  group('CashCollectionModel.fromJson', () {
    test('parses every field of a full real transaction', () {
      printTestDivider(
        'CashCollectionModel.fromJson parses every field of a full real transaction',
      );
      final row =
          (fixture()['data']['transactions'] as List).first
              as Map<String, dynamic>;
      final model = CashCollectionModel.fromJson(row);

      printTestLog('id → expected: "301", actual: ${model.id}');
      expect(model.id, '301');
      printTestLog('orderId → expected: "1006", actual: ${model.orderId}');
      expect(model.orderId, '1006');
      printTestLog(
        'orderNote → expected: "Leave at the gate", actual: ${model.orderNote}',
      );
      expect(model.orderNote, 'Leave at the gate');
      printTestLog(
        'paymentMethod → expected: "cod", actual: ${model.paymentMethod}',
      );
      expect(model.paymentMethod, 'cod');
      printTestLog('amount → expected: "560.00", actual: ${model.amount}');
      expect(model.amount, '560.00');
      printTestLog(
        'message → expected: "Cash collected for order #1006", actual: ${model.message}',
      );
      expect(model.message, 'Cash collected for order #1006');
      printTestLog('currency → expected: "₹", actual: ${model.currency}');
      expect(model.currency, '₹');
    });

    test('order_note missing falls back to empty string', () {
      printTestDivider(
        'CashCollectionModel.fromJson order_note missing falls back to empty string',
      );
      final model = CashCollectionModel.fromJson({'id': 1});

      printTestLog('orderNote → expected: "", actual: "${model.orderNote}"');
      expect(model.orderNote, '');
    });

    test('null/missing fields do not crash and stay null', () {
      printTestDivider(
        'CashCollectionModel.fromJson null/missing fields do not crash and stay null',
      );
      final model = CashCollectionModel.fromJson(const {});

      printTestLog('id → expected: null, actual: ${model.id}');
      expect(model.id, isNull);
      printTestLog('amount → expected: null, actual: ${model.amount}');
      expect(model.amount, isNull);
      printTestLog('currency → expected: null, actual: ${model.currency}');
      expect(model.currency, isNull);
    });

    test('numeric ids/amounts are stringified via toString', () {
      printTestDivider(
        'CashCollectionModel.fromJson numeric ids/amounts are stringified via toString',
      );
      final model = CashCollectionModel.fromJson({
        'id': 301,
        'amount': 560.5,
      });

      printTestLog('id → expected: "301", actual: ${model.id}');
      expect(model.id, '301');
      printTestLog('amount → expected: "560.5", actual: ${model.amount}');
      expect(model.amount, '560.5');
    });
  });
}
