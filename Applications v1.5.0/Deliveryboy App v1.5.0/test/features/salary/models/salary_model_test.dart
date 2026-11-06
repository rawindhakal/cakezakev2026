import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/salary/models/salary_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/salary/salary_list.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('SalaryModel.fromJson', () {
    test('parses every field of a full real payment entry', () {
      printTestDivider(
        'SalaryModel.fromJson parses every field of a full real payment entry',
      );
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final model = SalaryModel.fromJson(row);

      printTestLog('id → expected: 701, actual: ${model.id}');
      expect(model.id, 701);
      printTestLog('amount → expected: 25000.00, actual: ${model.amount}');
      expect(model.amount, 25000.00);
      printTestLog(
        'note → expected: "August 2026 salary", actual: "${model.note}"',
      );
      expect(model.note, 'August 2026 salary');
      printTestLog('paidOn → expected: "2026-08-01", actual: "${model.paidOn}"');
      expect(model.paidOn, '2026-08-01');
      printTestLog('currency → expected: "₹", actual: "${model.currency}"');
      expect(model.currency, '₹');
    });

    test('missing/null fields do not crash', () {
      printTestDivider('SalaryModel.fromJson missing/null fields do not crash');
      final model = SalaryModel.fromJson(const {});

      printTestLog('id → expected: null, actual: ${model.id}');
      expect(model.id, isNull);
      printTestLog(
        'amount → expected: 0.0 (toSafeDouble fallback, not null), actual: ${model.amount}',
      );
      expect(model.amount, 0.0);
      printTestLog('currency → expected: null, actual: ${model.currency}');
      expect(model.currency, isNull);
    });

    test('note/paidOn default to empty string, not null, when absent', () {
      printTestDivider(
        'SalaryModel.fromJson note/paidOn default to empty string, not null, when absent',
      );
      final model = SalaryModel.fromJson(const {'id': 1});

      printTestLog('note → expected: "", actual: "${model.note}"');
      expect(model.note, '');
      printTestLog('paidOn → expected: "", actual: "${model.paidOn}"');
      expect(model.paidOn, '');
    });

    test('note/paidOn default to empty string when explicitly null', () {
      printTestDivider(
        'SalaryModel.fromJson note/paidOn default to empty string when explicitly null',
      );
      final model = SalaryModel.fromJson(const {
        'id': 1,
        'note': null,
        'paid_on': null,
      });

      printTestLog('note → expected: "", actual: "${model.note}"');
      expect(model.note, '');
      printTestLog('paidOn → expected: "", actual: "${model.paidOn}"');
      expect(model.paidOn, '');
    });

    test('amount lenient-parses a numeric string via toSafeDouble', () {
      printTestDivider(
        'SalaryModel.fromJson amount lenient-parses a numeric string via toSafeDouble',
      );
      final model = SalaryModel.fromJson(const {'id': 1, 'amount': '499.99'});

      printTestLog('amount → expected: 499.99, actual: ${model.amount}');
      expect(model.amount, 499.99);
    });

    test('id lenient-parses a numeric string via toSafeIntOrNull', () {
      printTestDivider(
        'SalaryModel.fromJson id lenient-parses a numeric string via toSafeIntOrNull',
      );
      final model = SalaryModel.fromJson(const {'id': '701'});

      printTestLog('id → expected: 701, actual: ${model.id}');
      expect(model.id, 701);
    });
  });

  group('SalaryModel.toJson', () {
    test('round-trips a full model', () {
      printTestDivider('SalaryModel.toJson round-trips a full model');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final model = SalaryModel.fromJson(row);

      final json = model.toJson();
      final roundTripped = SalaryModel.fromJson(json);

      printTestLog('id → expected: ${model.id}, actual: ${roundTripped.id}');
      expect(roundTripped.id, model.id);
      printTestLog(
        'amount → expected: ${model.amount}, actual: ${roundTripped.amount}',
      );
      expect(roundTripped.amount, model.amount);
      printTestLog(
        'note → expected: "${model.note}", actual: "${roundTripped.note}"',
      );
      expect(roundTripped.note, model.note);
      printTestLog(
        'paidOn → expected: "${model.paidOn}", actual: "${roundTripped.paidOn}"',
      );
      expect(roundTripped.paidOn, model.paidOn);
      printTestLog(
        'currency → expected: "${model.currency}", actual: "${roundTripped.currency}"',
      );
      expect(roundTripped.currency, model.currency);
    });
  });
}
