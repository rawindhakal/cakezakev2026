import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/wallet/repositories/wallet_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late WalletRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/wallet/wallet_withdrawal_requests.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = WalletRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubGet(Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        ApiEndpoints.getWithdrawalRequests,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery() =>
      verify(
            () => mockApiClient.get(
              ApiEndpoints.getWithdrawalRequests,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getWithdrawalRequests', () {
    test('parses the real page and sends offset/limit by default', () async {
      printTestDivider(
        'getWithdrawalRequests parses the real page and sends offset/limit by default',
      );
      stubGet(fixture());

      final page = await repository.getWithdrawalRequests();

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
        'first id → expected: "501", actual: "${page.data.first.id}"',
      );
      expect(page.data.first.id, '501');
    });

    test('meta carries the wallet balance through as a double', () async {
      printTestDivider(
        'getWithdrawalRequests meta carries the wallet balance through as a double',
      );
      stubGet(fixture());

      final page = await repository.getWithdrawalRequests();

      printTestLog('meta → expected: 4520.75, actual: ${page.meta}');
      expect(page.meta, 4520.75);
    });

    test('sends search and status only when non-empty', () async {
      printTestDivider(
        'getWithdrawalRequests sends search and status only when non-empty',
      );
      stubGet(fixture());

      await repository.getWithdrawalRequests(
        search: 'John',
        status: '1',
        offset: 20,
      );

      final query = capturedQuery();
      printTestLog(
        'search → expected: "John", actual: "${query[ApiParameters.search]}"',
      );
      expect(query[ApiParameters.search], 'John');
      printTestLog(
        'status → expected: "1", actual: "${query[ApiParameters.status]}"',
      );
      expect(query[ApiParameters.status], '1');
      printTestLog('offset → expected: 20, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 20);
    });

    test('omits search/status that are null or empty', () async {
      printTestDivider(
        'getWithdrawalRequests omits search/status that are null or empty',
      );
      stubGet(fixture());

      await repository.getWithdrawalRequests(search: '', status: '');

      final query = capturedQuery();
      printTestLog(
        'search present → expected: false, actual: ${query.containsKey(ApiParameters.search)}',
      );
      expect(query.containsKey(ApiParameters.search), isFalse);
      printTestLog(
        'status present → expected: false, actual: ${query.containsKey(ApiParameters.status)}',
      );
      expect(query.containsKey(ApiParameters.status), isFalse);
    });

    test('status "0" (pending, a falsy-looking value) is still sent', () async {
      printTestDivider(
        'getWithdrawalRequests status "0" (pending, a falsy-looking value) is still sent',
      );
      stubGet(fixture());

      await repository.getWithdrawalRequests(status: '0');

      final query = capturedQuery();
      printTestLog(
        'status → expected: "0", actual: "${query[ApiParameters.status]}"',
      );
      expect(query[ApiParameters.status], '0');
    });

    test('a null data block returns an empty list and 0.0 balance without crashing', () async {
      printTestDivider(
        'getWithdrawalRequests a null data block returns an empty list and 0.0 balance without crashing',
      );
      stubGet({'total': 0, 'data': null});

      final page = await repository.getWithdrawalRequests();

      printTestLog('data → expected: [], actual: ${page.data}');
      expect(page.data, isEmpty);
      printTestLog('total → expected: 0, actual: ${page.total}');
      expect(page.total, 0);
      printTestLog('meta → expected: 0.0, actual: ${page.meta}');
      expect(page.meta, 0.0);
    });
  });

  group('addWithdrawalRequest', () {
    test('sends the amount field and omits message when not given', () async {
      printTestDivider(
        'addWithdrawalRequest sends the amount field and omits message when not given',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.addWithdrawalRequest,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.addWithdrawalRequest(amount: '500');

      final data =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.addWithdrawalRequest,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('amount → expected: "500", actual: "${data[ApiParameters.amount]}"');
      expect(data[ApiParameters.amount], '500');
      printTestLog(
        'message present → expected: false, actual: ${data.containsKey(ApiParameters.message)}',
      );
      expect(data.containsKey(ApiParameters.message), isFalse);
    });

    test('includes message when non-empty', () async {
      printTestDivider('addWithdrawalRequest includes message when non-empty');
      when(
        () => mockApiClient.post(
          ApiEndpoints.addWithdrawalRequest,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.addWithdrawalRequest(
        amount: '500',
        message: 'Need cash',
      );

      final data =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.addWithdrawalRequest,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'message → expected: "Need cash", actual: "${data[ApiParameters.message]}"',
      );
      expect(data[ApiParameters.message], 'Need cash');
    });

    test('omits an empty message string', () async {
      printTestDivider('addWithdrawalRequest omits an empty message string');
      when(
        () => mockApiClient.post(
          ApiEndpoints.addWithdrawalRequest,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.addWithdrawalRequest(amount: '500', message: '');

      final data =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.addWithdrawalRequest,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'message present → expected: false, actual: ${data.containsKey(ApiParameters.message)}',
      );
      expect(data.containsKey(ApiParameters.message), isFalse);
    });
  });
}
