import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/wallet/wallet_withdrawal_requests.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('Data.fromJson', () {
    test('parses the real payload: withdraw_requests list and balance', () {
      printTestDivider(
        'Data.fromJson parses the real payload: withdraw_requests list and balance',
      );
      final data = Data.fromJson(fixture()['data'] as Map<String, dynamic>);

      printTestLog(
        'withdrawRequests length → expected: 3, actual: ${data.withdrawRequests?.length}',
      );
      expect(data.withdrawRequests?.length, 3);
      printTestLog('balance → expected: "4520.75", actual: ${data.balance}');
      expect(data.balance, '4520.75');
    });

    test('missing withdraw_requests key stays null, not empty list', () {
      printTestDivider(
        'Data.fromJson missing withdraw_requests key stays null, not empty list',
      );
      final data = Data.fromJson({'balance': '100.00'});

      printTestLog(
        'withdrawRequests → expected: null, actual: ${data.withdrawRequests}',
      );
      expect(data.withdrawRequests, isNull);
    });

    test('null/missing fields do not crash', () {
      printTestDivider('Data.fromJson null/missing fields do not crash');
      final data = Data.fromJson(const {});

      printTestLog('balance → expected: null, actual: ${data.balance}');
      expect(data.balance, isNull);
      printTestLog(
        'withdrawRequests → expected: null, actual: ${data.withdrawRequests}',
      );
      expect(data.withdrawRequests, isNull);
    });

    test('balance passed as a number is stringified via toString', () {
      printTestDivider(
        'Data.fromJson balance passed as a number is stringified via toString',
      );
      final data = Data.fromJson({'balance': 4520.75});

      printTestLog('balance → expected: "4520.75", actual: ${data.balance}');
      expect(data.balance, '4520.75');
    });

    test('toJson round trip preserves shape', () {
      printTestDivider('Data.fromJson toJson round trip preserves shape');
      final data = Data.fromJson(fixture()['data'] as Map<String, dynamic>);

      final json = data.toJson();
      printTestLog(
        'withdraw_requests length → expected: 3, actual: ${(json['withdraw_requests'] as List).length}',
      );
      expect((json['withdraw_requests'] as List).length, 3);
      printTestLog('balance → expected: "4520.75", actual: ${json['balance']}');
      expect(json['balance'], '4520.75');
    });
  });

  group('WithdrawRequests.fromJson', () {
    test('parses every field of a full real transaction', () {
      printTestDivider(
        'WithdrawRequests.fromJson parses every field of a full real transaction',
      );
      final row =
          (fixture()['data']['withdraw_requests'] as List).first
              as Map<String, dynamic>;
      final model = WithdrawRequests.fromJson(row);

      printTestLog('id → expected: "501", actual: ${model.id}');
      expect(model.id, '501');
      printTestLog('type → expected: "withdrawal", actual: ${model.type}');
      expect(model.type, 'withdrawal');
      printTestLog('name → expected: "John Doe", actual: ${model.name}');
      expect(model.name, 'John Doe');
      printTestLog('balance → expected: "4520.75", actual: ${model.balance}');
      expect(model.balance, '4520.75');
      printTestLog('amount → expected: "1000.00", actual: ${model.amount}');
      expect(model.amount, '1000.00');
      printTestLog(
        'message → expected: "Need cash for fuel", actual: ${model.message}',
      );
      expect(model.message, 'Need cash for fuel');
      printTestLog('status → expected: "0", actual: ${model.status}');
      expect(model.status, '0');
      printTestLog(
        'deviceType → expected: "android", actual: ${model.deviceType}',
      );
      expect(model.deviceType, 'android');
      printTestLog(
        'createdAt → expected: "2026-08-18 10:15:00", actual: ${model.createdAt}',
      );
      expect(model.createdAt, '2026-08-18 10:15:00');
      printTestLog('currency → expected: "₹", actual: ${model.currency}');
      expect(model.currency, '₹');
    });

    test('null fields (remark, receipt_image_url) survive as real nulls', () {
      printTestDivider(
        'WithdrawRequests.fromJson null fields (remark, receipt_image_url) survive as real nulls',
      );
      final row =
          (fixture()['data']['withdraw_requests'] as List).first
              as Map<String, dynamic>;
      final model = WithdrawRequests.fromJson(row);

      printTestLog('remark → expected: null, actual: ${model.remark}');
      expect(model.remark, isNull);
      printTestLog(
        'receiptImageUrl → expected: null, actual: ${model.receiptImageUrl}',
      );
      expect(model.receiptImageUrl, isNull);
    });

    test('a remark/receipt_image_url present on an approved row parses', () {
      printTestDivider(
        'WithdrawRequests.fromJson a remark/receipt_image_url present on an approved row parses',
      );
      final row =
          (fixture()['data']['withdraw_requests'] as List)[1]
              as Map<String, dynamic>;
      final model = WithdrawRequests.fromJson(row);

      printTestLog(
        'remark → expected: "Approved and processed", actual: ${model.remark}',
      );
      expect(model.remark, 'Approved and processed');
      printTestLog(
        'receiptImageUrl → expected: non-null, actual: ${model.receiptImageUrl}',
      );
      expect(model.receiptImageUrl, isNotNull);
    });

    test('null/missing fields do not crash and stay null', () {
      printTestDivider(
        'WithdrawRequests.fromJson null/missing fields do not crash and stay null',
      );
      final model = WithdrawRequests.fromJson(const {});

      printTestLog('id → expected: null, actual: ${model.id}');
      expect(model.id, isNull);
      printTestLog('amount → expected: null, actual: ${model.amount}');
      expect(model.amount, isNull);
      printTestLog('status → expected: null, actual: ${model.status}');
      expect(model.status, isNull);
    });

    test('numeric id/amount are stringified via toString', () {
      printTestDivider(
        'WithdrawRequests.fromJson numeric id/amount are stringified via toString',
      );
      final model = WithdrawRequests.fromJson({'id': 501, 'amount': 1000.5});

      printTestLog('id → expected: "501", actual: ${model.id}');
      expect(model.id, '501');
      printTestLog('amount → expected: "1000.5", actual: ${model.amount}');
      expect(model.amount, '1000.5');
    });

    test('toJson round trip preserves every field', () {
      printTestDivider(
        'WithdrawRequests.fromJson toJson round trip preserves every field',
      );
      final row =
          (fixture()['data']['withdraw_requests'] as List).first
              as Map<String, dynamic>;
      final model = WithdrawRequests.fromJson(row);

      final json = model.toJson();
      printTestLog('id → expected: "501", actual: ${json['id']}');
      expect(json['id'], '501');
      printTestLog('amount → expected: "1000.00", actual: ${json['amount']}');
      expect(json['amount'], '1000.00');
      printTestLog(
        'created_at → expected: "2026-08-18 10:15:00", actual: ${json['created_at']}',
      );
      expect(json['created_at'], '2026-08-18 10:15:00');
    });
  });
}
