import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/settlement_history/settlement_history_list.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('SettlementHistoryResponse.fromJson', () {
    test('parses the envelope and every entry off the real payload', () {
      printTestDivider(
        'SettlementHistoryResponse.fromJson parses the envelope and every entry off the real payload',
      );
      final response = SettlementHistoryResponse.fromJson(fixture());

      printTestLog('status → expected: 1, actual: ${response.status}');
      expect(response.status, 1);
      printTestLog(
        'message → expected: "Settlement history fetched successfully", actual: "${response.message}"',
      );
      expect(response.message, 'Settlement history fetched successfully');
      printTestLog('total → expected: 3, actual: ${response.total}');
      expect(response.total, 3);
      printTestLog('data length → expected: 3, actual: ${response.data?.length}');
      expect(response.data?.length, 3);
    });

    test('a null data key leaves data null rather than an empty list', () {
      printTestDivider(
        'SettlementHistoryResponse.fromJson a null data key leaves data null rather than an empty list',
      );
      final response = SettlementHistoryResponse.fromJson(const {
        'status': 1,
        'total': 0,
        'data': null,
      });

      printTestLog('data → expected: null, actual: ${response.data}');
      expect(response.data, isNull);
    });

    test('a missing message key becomes an empty string, not null', () {
      printTestDivider(
        'SettlementHistoryResponse.fromJson a missing message key becomes an empty string, not null',
      );
      final response = SettlementHistoryResponse.fromJson(const {'status': 1});

      printTestLog('message → expected: "", actual: "${response.message}"');
      expect(response.message, '');
      printTestLog('status → expected: 1, actual: ${response.status}');
      expect(response.status, 1);
      printTestLog('total → expected: null, actual: ${response.total}');
      expect(response.total, isNull);
    });

    test('lenient-parses numeric strings in status/total', () {
      printTestDivider(
        'SettlementHistoryResponse.fromJson lenient-parses numeric strings in status/total',
      );
      final response = SettlementHistoryResponse.fromJson(const {
        'status': '1',
        'total': '42',
      });

      printTestLog('status → expected: 1, actual: ${response.status}');
      expect(response.status, 1);
      printTestLog('total → expected: 42, actual: ${response.total}');
      expect(response.total, 42);
    });

    test('a non-numeric status/total stays null instead of throwing', () {
      printTestDivider(
        'SettlementHistoryResponse.fromJson a non-numeric status/total stays null instead of throwing',
      );
      final response = SettlementHistoryResponse.fromJson(const {
        'status': 'ok',
        'total': 'many',
      });

      printTestLog('status → expected: null, actual: ${response.status}');
      expect(response.status, isNull);
      printTestLog('total → expected: null, actual: ${response.total}');
      expect(response.total, isNull);
    });
  });

  group('SettlementHistoryData.fromJson', () {
    test('parses every field off a full credit entry', () {
      printTestDivider(
        'SettlementHistoryData.fromJson parses every field off a full credit entry',
      );
      final entry = SettlementHistoryResponse.fromJson(fixture()).data!.first;

      printTestLog('id → expected: "901", actual: "${entry.id}"');
      expect(entry.id, '901');
      printTestLog('deliveryBoyId → expected: 42, actual: ${entry.deliveryBoyId}');
      expect(entry.deliveryBoyId, 42);
      printTestLog('name → expected: "Ravi Kumar", actual: "${entry.name}"');
      expect(entry.name, 'Ravi Kumar');
      printTestLog('mobile → expected: "9876543210", actual: "${entry.mobile}"');
      expect(entry.mobile, '9876543210');
      printTestLog('countryCode → expected: "91", actual: "${entry.countryCode}"');
      expect(entry.countryCode, '91');
      printTestLog(
        'entryType → expected: "delivery_commission", actual: "${entry.entryType}"',
      );
      expect(entry.entryType, 'delivery_commission');
      printTestLog('type → expected: "credit", actual: "${entry.type}"');
      expect(entry.type, 'credit');
      printTestLog('amount → expected: 150.75, actual: ${entry.amount}');
      expect(entry.amount, 150.75);
      printTestLog(
        'openingBalance → expected: 1200.0, actual: ${entry.openingBalance}',
      );
      expect(entry.openingBalance, 1200.0);
      printTestLog(
        'closingBalance → expected: 1350.75, actual: ${entry.closingBalance}',
      );
      expect(entry.closingBalance, 1350.75);
      printTestLog('currency → expected: "₹", actual: "${entry.currency}"');
      expect(entry.currency, '₹');
      printTestLog(
        'message → expected: "Commission for order #1006", actual: "${entry.message}"',
      );
      expect(entry.message, 'Commission for order #1006');
      printTestLog(
        'createdAt → expected: "2026-08-17 10:30:00", actual: "${entry.createdAt}"',
      );
      expect(entry.createdAt, '2026-08-17 10:30:00');
    });

    test('coerces a numeric id to a String', () {
      printTestDivider('SettlementHistoryData.fromJson coerces a numeric id to a String');
      final entry = SettlementHistoryData.fromJson(const {'id': 901});

      printTestLog('id → expected: "901" (String), actual: "${entry.id}" (${entry.id.runtimeType})');
      expect(entry.id, '901');
      expect(entry.id, isA<String>());
    });

    test('lenient-parses amounts sent as strings and as numbers alike', () {
      printTestDivider(
        'SettlementHistoryData.fromJson lenient-parses amounts sent as strings and as numbers alike',
      );
      final entries = SettlementHistoryResponse.fromJson(fixture()).data!;

      // Fixture entry 1 sends amounts as strings, entry 2 as numbers.
      printTestLog('string amount "150.75" → expected: 150.75, actual: ${entries[0].amount}');
      expect(entries[0].amount, 150.75);
      printTestLog('int amount 500 → expected: 500.0, actual: ${entries[1].amount}');
      expect(entries[1].amount, 500.0);
      printTestLog(
        'string openingBalance "1200.00" → expected: 1200.0, actual: ${entries[0].openingBalance}',
      );
      expect(entries[0].openingBalance, 1200.0);
    });

    test('amount/balances default to 0.0 when missing or null — never null', () {
      printTestDivider(
        'SettlementHistoryData.fromJson amount/balances default to 0.0 when missing or null — never null',
      );
      final missing = SettlementHistoryData.fromJson(const {});
      final explicitNull = SettlementHistoryData.fromJson(const {
        'amount': null,
        'opening_balance': null,
        'closing_balance': null,
      });

      for (final entry in [missing, explicitNull]) {
        printTestLog('amount → expected: 0.0, actual: ${entry.amount}');
        expect(entry.amount, 0.0);
        printTestLog('openingBalance → expected: 0.0, actual: ${entry.openingBalance}');
        expect(entry.openingBalance, 0.0);
        printTestLog('closingBalance → expected: 0.0, actual: ${entry.closingBalance}');
        expect(entry.closingBalance, 0.0);
      }
    });

    test('a non-numeric amount falls back to 0.0 instead of throwing', () {
      printTestDivider(
        'SettlementHistoryData.fromJson a non-numeric amount falls back to 0.0 instead of throwing',
      );
      final entry = SettlementHistoryData.fromJson(const {'amount': 'N/A'});

      printTestLog('amount → expected: 0.0, actual: ${entry.amount}');
      expect(entry.amount, 0.0);
    });

    test('string fields stay null when missing — unlike the numeric ones', () {
      printTestDivider(
        'SettlementHistoryData.fromJson string fields stay null when missing — unlike the numeric ones',
      );
      final entry = SettlementHistoryData.fromJson(const {});

      printTestLog('id → expected: null, actual: ${entry.id}');
      expect(entry.id, isNull);
      printTestLog('entryType → expected: null, actual: ${entry.entryType}');
      expect(entry.entryType, isNull);
      printTestLog('type → expected: null, actual: ${entry.type}');
      expect(entry.type, isNull);
      printTestLog('currency → expected: null, actual: ${entry.currency}');
      expect(entry.currency, isNull);
      printTestLog('message → expected: null, actual: ${entry.message}');
      expect(entry.message, isNull);
      printTestLog('createdAt → expected: null, actual: ${entry.createdAt}');
      expect(entry.createdAt, isNull);
      printTestLog('deliveryBoyId → expected: null, actual: ${entry.deliveryBoyId}');
      expect(entry.deliveryBoyId, isNull);
    });

    test('a null message stays null rather than becoming the string "null"', () {
      printTestDivider(
        'SettlementHistoryData.fromJson a null message stays null rather than becoming the string "null"',
      );
      // Fixture entry 3 sends `"message": null` explicitly.
      final entry = SettlementHistoryResponse.fromJson(fixture()).data![2];

      printTestLog('message → expected: null, actual: ${entry.message}');
      expect(entry.message, isNull);
    });
  });

  group('SettlementHistoryData.toJson', () {
    test('round trips a full entry back to the api key names', () {
      printTestDivider(
        'SettlementHistoryData.toJson round trips a full entry back to the api key names',
      );
      final source = fixture()['data'][0] as Map<String, dynamic>;
      final json = SettlementHistoryData.fromJson(source).toJson();

      printTestLog('id → expected: "901", actual: "${json['id']}"');
      expect(json['id'], '901');
      printTestLog(
        'delivery_boy_id → expected: 42, actual: ${json['delivery_boy_id']}',
      );
      expect(json['delivery_boy_id'], 42);
      printTestLog('entry_type → expected: "delivery_commission", actual: "${json['entry_type']}"');
      expect(json['entry_type'], 'delivery_commission');
      printTestLog('type → expected: "credit", actual: "${json['type']}"');
      expect(json['type'], 'credit');
      // Numeric fields normalise to double on the way through fromJson, so
      // the round trip is value-preserving but not byte-identical to the
      // string the api sent.
      printTestLog('amount → expected: 150.75, actual: ${json['amount']}');
      expect(json['amount'], 150.75);
      printTestLog('opening_balance → expected: 1200.0, actual: ${json['opening_balance']}');
      expect(json['opening_balance'], 1200.0);
      printTestLog('closing_balance → expected: 1350.75, actual: ${json['closing_balance']}');
      expect(json['closing_balance'], 1350.75);
      printTestLog('currency → expected: "₹", actual: "${json['currency']}"');
      expect(json['currency'], '₹');
      printTestLog('created_at → expected: "2026-08-17 10:30:00", actual: "${json['created_at']}"');
      expect(json['created_at'], '2026-08-17 10:30:00');
    });

    test('emits every key even when the entry is empty', () {
      printTestDivider(
        'SettlementHistoryData.toJson emits every key even when the entry is empty',
      );
      final json = SettlementHistoryData().toJson();

      const keys = [
        'id',
        'delivery_boy_id',
        'name',
        'mobile',
        'country_code',
        'entry_type',
        'type',
        'amount',
        'opening_balance',
        'closing_balance',
        'currency',
        'message',
        'created_at',
      ];
      printTestLog('keys → expected: ${keys.length}, actual: ${json.keys.length}');
      expect(json.keys, containsAll(keys));
      expect(json.keys.length, keys.length);
    });
  });
}
