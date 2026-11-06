import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_entry_type.dart';

import '../../../helpers/test_logging.dart';

/// The enum's `value` strings are the wire format for the api's `entry_type`
/// filter — a typo here silently sends a filter the backend ignores, so each
/// one is asserted literally rather than round-tripped through the enum.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  const expectedValues = {
    SettlementEntryType.all: '',
    SettlementEntryType.deliveryCommission: 'delivery_commission',
    SettlementEntryType.returnCommission: 'return_commission',
    SettlementEntryType.withdrawal: 'withdrawal',
    SettlementEntryType.cashDepositCash: 'cash_deposit_cash',
    SettlementEntryType.cashDepositWallet: 'cash_deposit_wallet',
  };

  test('every entry type carries the api filter string the backend expects', () {
    printTestDivider(
      'SettlementEntryType every entry type carries the api filter string the backend expects',
    );
    expectedValues.forEach((type, value) {
      printTestLog('${type.name}.value → expected: "$value", actual: "${type.value}"');
      expect(type.value, value);
    });
    printTestLog(
      'total types → expected: ${expectedValues.length}, actual: ${SettlementEntryType.values.length}',
    );
    expect(SettlementEntryType.values.length, expectedValues.length);
  });

  test('fromValue round trips every known value', () {
    printTestDivider('SettlementEntryType fromValue round trips every known value');
    for (final type in SettlementEntryType.values) {
      final actual = SettlementEntryType.fromValue(type.value);
      printTestLog('fromValue("${type.value}") → expected: ${type.name}, actual: ${actual.name}');
      expect(actual, type);
    }
  });

  test('fromValue falls back to all for an unknown value', () {
    printTestDivider(
      'SettlementEntryType fromValue falls back to all for an unknown value',
    );
    for (final raw in ['bonus', 'DELIVERY_COMMISSION', 'null']) {
      final actual = SettlementEntryType.fromValue(raw);
      printTestLog('fromValue("$raw") → expected: all, actual: ${actual.name}');
      expect(actual, SettlementEntryType.all);
    }
  });

  test('fromValue maps the empty string to all — the "no filter" case', () {
    printTestDivider(
      'SettlementEntryType fromValue maps the empty string to all — the "no filter" case',
    );
    final actual = SettlementEntryType.fromValue('');
    printTestLog('fromValue("") → expected: all, actual: ${actual.name}');
    expect(actual, SettlementEntryType.all);
  });
}
