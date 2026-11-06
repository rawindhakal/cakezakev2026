import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';
import 'package:deliveryboy/features/cash_collection/repositories/cash_collection_repositories.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late CashCollectionRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/cash_collection/cash_collections_list.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = CashCollectionRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubGet(Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        ApiEndpoints.cashCollection,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery() =>
      verify(
            () => mockApiClient.get(
              ApiEndpoints.cashCollection,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getCashCollections', () {
    test('parses the real page and sends offset/limit by default', () async {
      printTestDivider(
        'getCashCollections parses the real page and sends offset/limit by default',
      );
      stubGet(fixture());

      final page = await repository.getCashCollections();

      final query = capturedQuery();
      printTestLog(
        'offset → expected: 0, actual: ${query[ApiParameters.offset]}',
      );
      expect(query[ApiParameters.offset], 0);
      printTestLog(
        'limit → expected: ${AppConfig.pageLimit}, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], AppConfig.pageLimit);
      printTestLog('data length → expected: 3, actual: ${page.data.length}');
      expect(page.data.length, 3);
      printTestLog('total → expected: 3, actual: ${page.total}');
      expect(page.total, 3);
      printTestLog(
        'first orderId → expected: "1006", actual: "${page.data.first.orderId}"',
      );
      expect(page.data.first.orderId, '1006');
    });

    test('meta carries cashInHand/cashCollected through from the response', () async {
      printTestDivider(
        'getCashCollections meta carries cashInHand/cashCollected through from the response',
      );
      stubGet(fixture());

      final page = await repository.getCashCollections();

      final meta = page.meta as CashCollectionMeta;
      printTestLog('cashInHand → expected: "1245.50", actual: ${meta.cashInHand}');
      expect(meta.cashInHand, '1245.50');
      printTestLog(
        'cashCollected → expected: "8420.75", actual: ${meta.cashCollected}',
      );
      expect(meta.cashCollected, '8420.75');
    });

    test('sends every filter that has a value', () async {
      printTestDivider('getCashCollections sends every filter that has a value');
      stubGet(fixture());

      await repository.getCashCollections(
        search: 'TXN',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
        offset: 20,
      );

      final query = capturedQuery();
      printTestLog('search → expected: "TXN", actual: "${query[ApiParameters.search]}"');
      expect(query[ApiParameters.search], 'TXN');
      printTestLog(
        'startDate → expected: "2026-08-01", actual: "${query[ApiParameters.startDate]}"',
      );
      expect(query[ApiParameters.startDate], '2026-08-01');
      printTestLog(
        'endDate → expected: "2026-08-17", actual: "${query[ApiParameters.endDate]}"',
      );
      expect(query[ApiParameters.endDate], '2026-08-17');
      printTestLog('offset → expected: 20, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 20);
    });

    test('omits filters that are null or empty', () async {
      printTestDivider('getCashCollections omits filters that are null or empty');
      stubGet(fixture());

      await repository.getCashCollections(search: '', startDate: null, endDate: '');

      final query = capturedQuery();
      printTestLog(
        'search present → expected: false, actual: ${query.containsKey(ApiParameters.search)}',
      );
      expect(query.containsKey(ApiParameters.search), isFalse);
      printTestLog(
        'startDate present → expected: false, actual: ${query.containsKey(ApiParameters.startDate)}',
      );
      expect(query.containsKey(ApiParameters.startDate), isFalse);
      printTestLog(
        'endDate present → expected: false, actual: ${query.containsKey(ApiParameters.endDate)}',
      );
      expect(query.containsKey(ApiParameters.endDate), isFalse);
    });

    test('a null data block returns an empty list without crashing', () async {
      printTestDivider(
        'getCashCollections a null data block returns an empty list without crashing',
      );
      stubGet({'total': 0, 'data': null});

      final page = await repository.getCashCollections();

      printTestLog('data → expected: [], actual: ${page.data}');
      expect(page.data, isEmpty);
      printTestLog('total → expected: 0, actual: ${page.total}');
      expect(page.total, 0);
    });
  });
}
