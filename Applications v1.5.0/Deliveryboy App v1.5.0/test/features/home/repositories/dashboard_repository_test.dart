import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/home/repositories/dashboard_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late DashboardRepository repository;
  late Map<String, dynamic> response;

  setUpAll(() {
    registerApiClientFallbackValues();
    response =
        jsonDecode(
              File(
                'test/fixtures/home/dashboard_response.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  setUp(() {
    mockApiClient = MockApiClient();
    repository = DashboardRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('GETs the dashboard endpoint and parses the response', () async {
    printTestDivider('GETs the dashboard endpoint and parses the response');
    when(
      () => mockApiClient.get(
        ApiEndpoints.dashboard,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);

    final result = await repository.getDashboard();

    printTestLog('profile name → expected: "Alex Johnson", actual: "${result.data?.profile?.name}"');
    expect(result.data?.profile?.name, 'Alex Johnson');
    printTestLog('wallet balance → expected: 462.95, actual: ${result.data?.wallet?.balance}');
    expect(result.data?.wallet?.balance, 462.95);
  });

  test('defaults the trend query parameter to the last 7 days', () async {
    printTestDivider('defaults the trend query parameter to the last 7 days');
    when(
      () => mockApiClient.get(
        ApiEndpoints.dashboard,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);

    await repository.getDashboard();

    final captured = verify(
      () => mockApiClient.get(
        ApiEndpoints.dashboard,
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    printTestLog('queryParameters[trend] → expected: "7", actual: "${captured['trend']}"');
    expect(captured['trend'], '7');
  });

  test('forwards an explicit trend window', () async {
    printTestDivider('forwards an explicit trend window');
    when(
      () => mockApiClient.get(
        ApiEndpoints.dashboard,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);

    await repository.getDashboard(trend: '12m');

    final captured = verify(
      () => mockApiClient.get(
        ApiEndpoints.dashboard,
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    printTestLog('queryParameters[trend] → expected: "12m", actual: "${captured['trend']}"');
    expect(captured['trend'], '12m');
  });

  test('lets an ApiException from the client propagate', () async {
    printTestDivider('lets an ApiException from the client propagate');
    when(
      () => mockApiClient.get(
        ApiEndpoints.dashboard,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(const ApiException(message: 'Dashboard unavailable'));

    printTestLog('expected: throws ApiException, actual: calling now...');
    expect(repository.getDashboard(), throwsA(isA<ApiException>()));
  });
}
