import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/faq/repositories/faq_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late FaqRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/faq/faq_list.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = FaqRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubGet(Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        ApiEndpoints.faq,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery() =>
      verify(
            () => mockApiClient.get(
              ApiEndpoints.faq,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getFaqs', () {
    test('hits the faq endpoint and sends offset/limit by default', () async {
      printTestDivider(
        'getFaqs hits the faq endpoint and sends offset/limit by default',
      );
      stubGet(fixture());

      final response = await repository.getFaqs();

      final query = capturedQuery();
      printTestLog(
        'offset → expected: 0, actual: ${query[ApiParameters.offset]}',
      );
      expect(query[ApiParameters.offset], 0);
      printTestLog(
        'limit → expected: ${AppConfig.pageLimit}, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], AppConfig.pageLimit);
      printTestLog(
        'data length → expected: 3, actual: ${response.data?.length}',
      );
      expect(response.data, hasLength(3));
      printTestLog('total → expected: "3", actual: "${response.total}"');
      expect(response.total, '3');
    });

    test('forwards a custom offset/limit', () async {
      printTestDivider('getFaqs forwards a custom offset/limit');
      stubGet(fixture());

      await repository.getFaqs(offset: 20, limit: 5);

      final query = capturedQuery();
      printTestLog(
        'offset → expected: 20, actual: ${query[ApiParameters.offset]}',
      );
      expect(query[ApiParameters.offset], 20);
      printTestLog(
        'limit → expected: 5, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], 5);
    });

    test('parses every entry via FaqData.fromJson', () async {
      printTestDivider('getFaqs parses every entry via FaqData.fromJson');
      stubGet(fixture());

      final response = await repository.getFaqs();

      final entry = response.data!.first;
      printTestLog(
        'question → expected: "How do I track my order?", actual: "${entry.question}"',
      );
      expect(entry.question, 'How do I track my order?');
      printTestLog('lang → expected: "en", actual: "${entry.lang}"');
      expect(entry.lang, 'en');
    });

    test('a null data block returns an empty list without crashing', () async {
      printTestDivider(
        'getFaqs a null data block returns an empty list without crashing',
      );
      stubGet({'status': '1', 'total': '0', 'data': null});

      final response = await repository.getFaqs();

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
      printTestLog('total → expected: "0", actual: "${response.total}"');
      expect(response.total, '0');
    });

    test('a missing data key returns an empty list without crashing', () async {
      printTestDivider(
        'getFaqs a missing data key returns an empty list without crashing',
      );
      stubGet({'status': '1', 'total': '0'});

      final response = await repository.getFaqs();

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });
  });
}
