import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/settlement_history/repositories/settlement_history_repositories.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late SettlementHistoryRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/settlement_history/settlement_history_list.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = SettlementHistoryRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubGet(Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        ApiEndpoints.settlementHistory,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery() =>
      verify(
            () => mockApiClient.get(
              ApiEndpoints.settlementHistory,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getSettlementHistorys', () {
    test('hits the settlement_history endpoint with default offset/limit', () async {
      printTestDivider(
        'getSettlementHistorys hits the settlement_history endpoint with default offset/limit',
      );
      stubGet(fixture());

      await repository.getSettlementHistorys();

      final query = capturedQuery();
      printTestLog('offset → expected: 0, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 0);
      printTestLog(
        'limit → expected: ${AppConfig.pageLimit}, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], AppConfig.pageLimit);
    });

    test('parses the real page into typed entries', () async {
      printTestDivider('getSettlementHistorys parses the real page into typed entries');
      stubGet(fixture());

      final response = await repository.getSettlementHistorys();

      printTestLog('data length → expected: 3, actual: ${response.data?.length}');
      expect(response.data?.length, 3);
      printTestLog('total → expected: 3, actual: ${response.total}');
      expect(response.total, 3);
      printTestLog('first id → expected: "901", actual: "${response.data?.first.id}"');
      expect(response.data?.first.id, '901');
      printTestLog(
        'first entryType → expected: "delivery_commission", actual: "${response.data?.first.entryType}"',
      );
      expect(response.data?.first.entryType, 'delivery_commission');
      printTestLog('first amount → expected: 150.75, actual: ${response.data?.first.amount}');
      expect(response.data?.first.amount, 150.75);
    });

    test('forwards a custom offset and limit', () async {
      printTestDivider('getSettlementHistorys forwards a custom offset and limit');
      stubGet(fixture());

      await repository.getSettlementHistorys(offset: 20, limit: 5);

      final query = capturedQuery();
      printTestLog('offset → expected: 20, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 20);
      printTestLog('limit → expected: 5, actual: ${query[ApiParameters.limit]}');
      expect(query[ApiParameters.limit], 5);
    });

    test('sends every filter that has a value', () async {
      printTestDivider('getSettlementHistorys sends every filter that has a value');
      stubGet(fixture());

      await repository.getSettlementHistorys(
        search: '901',
        entryType: 'withdrawal',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      );

      final query = capturedQuery();
      printTestLog('search → expected: "901", actual: "${query[ApiParameters.search]}"');
      expect(query[ApiParameters.search], '901');
      printTestLog(
        'entry_type → expected: "withdrawal", actual: "${query[ApiParameters.entryType]}"',
      );
      expect(query[ApiParameters.entryType], 'withdrawal');
      printTestLog(
        'start_date → expected: "2026-08-01", actual: "${query[ApiParameters.startDate]}"',
      );
      expect(query[ApiParameters.startDate], '2026-08-01');
      printTestLog(
        'end_date → expected: "2026-08-17", actual: "${query[ApiParameters.endDate]}"',
      );
      expect(query[ApiParameters.endDate], '2026-08-17');
    });

    test('omits filters that are null or empty', () async {
      printTestDivider('getSettlementHistorys omits filters that are null or empty');
      stubGet(fixture());

      await repository.getSettlementHistorys(
        search: '',
        entryType: '',
        startDate: null,
        endDate: '',
      );

      final query = capturedQuery();
      for (final key in [
        ApiParameters.search,
        ApiParameters.entryType,
        ApiParameters.startDate,
        ApiParameters.endDate,
      ]) {
        printTestLog('"$key" present → expected: false, actual: ${query.containsKey(key)}');
        expect(query.containsKey(key), isFalse);
      }
    });

    test('the "all" entry type sends no entry_type filter at all', () async {
      printTestDivider(
        'getSettlementHistorys the "all" entry type sends no entry_type filter at all',
      );
      stubGet(fixture());

      // SettlementEntryType.all's wire value is the empty string, which the
      // repository treats as "no filter" rather than sending `entry_type=`.
      await repository.getSettlementHistorys(entryType: '');

      final query = capturedQuery();
      printTestLog(
        'entry_type present → expected: false, actual: ${query.containsKey(ApiParameters.entryType)}',
      );
      expect(query.containsKey(ApiParameters.entryType), isFalse);
    });

    test('a null data block returns a null list without crashing', () async {
      printTestDivider(
        'getSettlementHistorys a null data block returns a null list without crashing',
      );
      stubGet(const {'status': 1, 'total': 0, 'data': null});

      final response = await repository.getSettlementHistorys();

      printTestLog('data → expected: null, actual: ${response.data}');
      expect(response.data, isNull);
      printTestLog('total → expected: 0, actual: ${response.total}');
      expect(response.total, 0);
    });

    test('a missing data key returns a null list without crashing', () async {
      printTestDivider(
        'getSettlementHistorys a missing data key returns a null list without crashing',
      );
      stubGet(const {'status': 1, 'total': 0});

      final response = await repository.getSettlementHistorys();

      printTestLog('data → expected: null, actual: ${response.data}');
      expect(response.data, isNull);
    });
  });
}
