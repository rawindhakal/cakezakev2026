import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_direction.dart';

import '../../../helpers/test_logging.dart';

/// [SettlementDirection.fromValue] is deliberately not symmetric: only the
/// literal "credit" (case-insensitively) is a credit, and *everything* else —
/// including null, an empty string, or an unknown server value — falls back to
/// debit. These tests pin that asymmetry down, since the card's `+`/`-` sign
/// and accent colour both hang off it.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('maps "credit" to credit', () {
    printTestDivider('SettlementDirection maps "credit" to credit');
    final actual = SettlementDirection.fromValue('credit');
    printTestLog('fromValue("credit") → expected: credit, actual: $actual');
    expect(actual, SettlementDirection.credit);
  });

  test('is case-insensitive on "credit"', () {
    printTestDivider('SettlementDirection is case-insensitive on "credit"');
    for (final raw in ['CREDIT', 'Credit', 'cReDiT']) {
      final actual = SettlementDirection.fromValue(raw);
      printTestLog('fromValue("$raw") → expected: credit, actual: $actual');
      expect(actual, SettlementDirection.credit);
    }
  });

  test('maps "debit" to debit', () {
    printTestDivider('SettlementDirection maps "debit" to debit');
    final actual = SettlementDirection.fromValue('debit');
    printTestLog('fromValue("debit") → expected: debit, actual: $actual');
    expect(actual, SettlementDirection.debit);
  });

  test('falls back to debit for null, empty and unknown values', () {
    printTestDivider(
      'SettlementDirection falls back to debit for null, empty and unknown values',
    );
    for (final raw in [null, '', ' credit', 'refund', 'null']) {
      final actual = SettlementDirection.fromValue(raw);
      printTestLog('fromValue(${raw == null ? 'null' : '"$raw"'}) → expected: debit, actual: $actual');
      expect(actual, SettlementDirection.debit);
    }
  });
}
