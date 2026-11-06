import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/salary/repositories/salary_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late SalaryRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/salary/salary_list.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = SalaryRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubGet(Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        ApiEndpoints.salary,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery() =>
      verify(
            () => mockApiClient.get(
              ApiEndpoints.salary,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getSalaries', () {
    test('hits the salary endpoint and sends offset/limit by default', () async {
      printTestDivider(
        'getSalaries hits the salary endpoint and sends offset/limit by default',
      );
      stubGet(fixture());

      final page = await repository.getSalaries();

      final query = capturedQuery();
      printTestLog('offset → expected: 0, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 0);
      printTestLog(
        'limit → expected: ${AppConfig.pageLimit}, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], AppConfig.pageLimit);
      printTestLog('data length → expected: 3, actual: ${page.data.length}');
      expect(page.data.length, 3);
      printTestLog('total → expected: 3, actual: ${page.total}');
      expect(page.total, 3);
      printTestLog('first id → expected: 701, actual: ${page.data.first.id}');
      expect(page.data.first.id, 701);
    });

    test('forwards a custom offset/limit', () async {
      printTestDivider('getSalaries forwards a custom offset/limit');
      stubGet(fixture());

      await repository.getSalaries(offset: 20, limit: 5);

      final query = capturedQuery();
      printTestLog('offset → expected: 20, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 20);
      printTestLog('limit → expected: 5, actual: ${query[ApiParameters.limit]}');
      expect(query[ApiParameters.limit], 5);
    });

    test('parses every field via SalaryModel.fromJson', () async {
      printTestDivider('getSalaries parses every field via SalaryModel.fromJson');
      stubGet(fixture());

      final page = await repository.getSalaries();

      final entry = page.data.first;
      printTestLog('amount → expected: 25000.0, actual: ${entry.amount}');
      expect(entry.amount, 25000.0);
      printTestLog('note → expected: "August 2026 salary", actual: "${entry.note}"');
      expect(entry.note, 'August 2026 salary');
      printTestLog('paidOn → expected: "2026-08-01", actual: "${entry.paidOn}"');
      expect(entry.paidOn, '2026-08-01');
      printTestLog('currency → expected: "₹", actual: "${entry.currency}"');
      expect(entry.currency, '₹');
    });

    test('a null data block returns an empty list without crashing', () async {
      printTestDivider(
        'getSalaries a null data block returns an empty list without crashing',
      );
      stubGet({'total': 0, 'data': null});

      final page = await repository.getSalaries();

      printTestLog('data → expected: [], actual: ${page.data}');
      expect(page.data, isEmpty);
      printTestLog('total → expected: 0, actual: ${page.total}');
      expect(page.total, 0);
    });

    test('a missing data key returns an empty list without crashing', () async {
      printTestDivider(
        'getSalaries a missing data key returns an empty list without crashing',
      );
      stubGet({'total': 0});

      final page = await repository.getSalaries();

      printTestLog('data → expected: [], actual: ${page.data}');
      expect(page.data, isEmpty);
    });
  });
}
