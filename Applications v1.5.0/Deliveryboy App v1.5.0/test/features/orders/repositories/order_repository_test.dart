import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late OrderRepository repository;

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  setUpAll(registerApiClientFallbackValues);

  setUp(() {
    mockApiClient = MockApiClient();
    repository = OrderRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  /// Stubs a GET on [endpoint] and returns the captured query parameters.
  void stubGet(String endpoint, Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        endpoint,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery(String endpoint) =>
      verify(
            () => mockApiClient.get(
              endpoint,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getOrders', () {
    test('parses the real page and sends offset/limit by default', () async {
      printTestDivider('getOrders parses the real page and sends offset/limit by default');
      stubGet(ApiEndpoints.orders, fixture('orders_list'));

      final page = await repository.getOrders();

      final query = capturedQuery(ApiEndpoints.orders);
      printTestLog('offset → expected: 0, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 0);
      printTestLog('limit → expected: ${AppConfig.pageLimit}, actual: ${query[ApiParameters.limit]}');
      expect(query[ApiParameters.limit], AppConfig.pageLimit);
      printTestLog('data length → expected: 10, actual: ${page.data.length}');
      expect(page.data.length, 10);
      printTestLog('total → expected: 27, actual: ${page.total}');
      expect(page.total, 27);
      printTestLog('first order → expected: "SB-ORD-00006", actual: "${page.data.first.orderNumber}"');
      expect(page.data.first.orderNumber, 'SB-ORD-00006');
    });

    test('sends every filter that has a value', () async {
      printTestDivider('getOrders sends every filter that has a value');
      stubGet(ApiEndpoints.orders, fixture('orders_list'));

      await repository.getOrders(
        status: '5',
        search: 'SB-ORD',
        startDeliveryDate: '2026-08-01',
        endDeliveryDate: '2026-08-17',
        offset: 20,
      );

      final query = capturedQuery(ApiEndpoints.orders);
      printTestLog('status → expected: "5", actual: "${query[ApiParameters.status]}"');
      expect(query[ApiParameters.status], '5');
      printTestLog('search → expected: "SB-ORD", actual: "${query[ApiParameters.search]}"');
      expect(query[ApiParameters.search], 'SB-ORD');
      printTestLog('startDate → expected: "2026-08-01", actual: "${query[ApiParameters.startDate]}"');
      expect(query[ApiParameters.startDate], '2026-08-01');
      printTestLog('offset → expected: 20, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 20);
    });

    test('omits filters that are null or empty', () async {
      printTestDivider('getOrders omits filters that are null or empty');
      stubGet(ApiEndpoints.orders, fixture('orders_list'));

      await repository.getOrders(status: '', search: null, startDeliveryDate: '');

      final query = capturedQuery(ApiEndpoints.orders);
      printTestLog('status present → expected: false, actual: ${query.containsKey(ApiParameters.status)}');
      expect(query.containsKey(ApiParameters.status), isFalse);
      printTestLog('search present → expected: false, actual: ${query.containsKey(ApiParameters.search)}');
      expect(query.containsKey(ApiParameters.search), isFalse);
      printTestLog('startDate present → expected: false, actual: ${query.containsKey(ApiParameters.startDate)}');
      expect(query.containsKey(ApiParameters.startDate), isFalse);
    });
  });

  group('getOrderById', () {
    test('sends the order id and parses the detail', () async {
      printTestDivider('getOrderById sends the order id and parses the detail');
      stubGet(ApiEndpoints.orderById, fixture('order_detail'));

      final detail = await repository.getOrderById('6');

      verify(
        () => mockApiClient.get(
          ApiEndpoints.orderById,
          queryParameters: {ApiParameters.orderId: '6'},
        ),
      ).called(1);
      printTestLog('order number → expected: "SB-ORD-00006", actual: "${detail.data?.order?.orderNumber}"');
      expect(detail.data?.order?.orderNumber, 'SB-ORD-00006');
      printTestLog('items → expected: 3, actual: ${detail.data?.orderItems?.length}');
      expect(detail.data?.orderItems?.length, 3);
    });
  });

  group('getOrderStatuses', () {
    test('parses both status lists', () async {
      printTestDivider('getOrderStatuses parses both status lists');
      stubGet(ApiEndpoints.orderStatuses, fixture('order_statuses'));

      final statuses = await repository.getOrderStatuses();

      printTestLog('data → expected: 4, actual: ${statuses.data?.length}');
      expect(statuses.data?.length, 4);
      printTestLog('return statuses → expected: 3, actual: ${statuses.returnStatuses?.length}');
      expect(statuses.returnStatuses?.length, 3);
    });

    test('sends the channel only when one is given', () async {
      printTestDivider('getOrderStatuses sends the channel only when one is given');
      stubGet(ApiEndpoints.orderStatuses, fixture('ecommerce_order_statuses'));

      await repository.getOrderStatuses(channel: 'ecommerce');
      var query = capturedQuery(ApiEndpoints.orderStatuses);
      printTestLog('channel → expected: "ecommerce", actual: "${query['channel']}"');
      expect(query['channel'], 'ecommerce');

      mockApiClient = MockApiClient();
      repository = OrderRepository(apiClient: mockApiClient);
      stubGet(ApiEndpoints.orderStatuses, fixture('order_statuses'));

      await repository.getOrderStatuses();
      query = capturedQuery(ApiEndpoints.orderStatuses);
      printTestLog('channel present → expected: false, actual: ${query.containsKey('channel')}');
      expect(query.containsKey('channel'), isFalse);
    });
  });

  group('getReturnOrders', () {
    test('parses the real page', () async {
      printTestDivider('getReturnOrders parses the real page');
      stubGet(ApiEndpoints.returnRequests, fixture('return_orders_list'));

      final page = await repository.getReturnOrders();

      printTestLog('data length → expected: 8, actual: ${page.data.length}');
      expect(page.data.length, 8);
      printTestLog('total → expected: 8, actual: ${page.total}');
      expect(page.total, 8);
      printTestLog('first return → expected: "RET-00023", actual: "${page.data.first.returnNumber}"');
      expect(page.data.first.returnNumber, 'RET-00023');
    });

    test('sends the filters it was given', () async {
      printTestDivider('getReturnOrders sends the filters it was given');
      stubGet(ApiEndpoints.returnRequests, fixture('return_orders_list'));

      await repository.getReturnOrders(
        status: '7',
        search: 'RET',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
        offset: 10,
      );

      final query = capturedQuery(ApiEndpoints.returnRequests);
      printTestLog('status → expected: "7", actual: "${query[ApiParameters.status]}"');
      expect(query[ApiParameters.status], '7');
      printTestLog('offset → expected: 10, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 10);
    });
  });

  group('getReturnRequestById', () {
    test('sends the return request id and parses the detail', () async {
      printTestDivider('getReturnRequestById sends the return request id and parses the detail');
      stubGet(ApiEndpoints.returnRequests, fixture('return_order_detail'));

      final detail = await repository.getReturnRequestById('23');

      verify(
        () => mockApiClient.get(
          ApiEndpoints.returnRequests,
          queryParameters: {'return_request_id': '23'},
        ),
      ).called(1);
      printTestLog('returnNumber → expected: non-empty, actual: "${detail.data?.returnNumber}"');
      expect(detail.data?.returnNumber, isNotEmpty);
    });
  });

  group('getEcommerceOrders', () {
    test('parses the real page', () async {
      printTestDivider('getEcommerceOrders parses the real page');
      stubGet(ApiEndpoints.ecomOrders, fixture('ecommerce_orders_list'));

      final page = await repository.getEcommerceOrders();

      printTestLog('data length → expected: 5, actual: ${page.data.length}');
      expect(page.data.length, 5);
      printTestLog('first item id → expected: 413, actual: ${page.data.first.id}');
      expect(page.data.first.id, 413);
    });

    test('omits an empty status but sends a real one', () async {
      printTestDivider('getEcommerceOrders omits an empty status but sends a real one');
      stubGet(ApiEndpoints.ecomOrders, fixture('ecommerce_orders_list'));

      await repository.getEcommerceOrders(status: '', startDate: '');
      var query = capturedQuery(ApiEndpoints.ecomOrders);
      printTestLog('status present → expected: false, actual: ${query.containsKey('status')}');
      expect(query.containsKey('status'), isFalse);

      mockApiClient = MockApiClient();
      repository = OrderRepository(apiClient: mockApiClient);
      stubGet(ApiEndpoints.ecomOrders, fixture('ecommerce_orders_list'));

      await repository.getEcommerceOrders(status: '6');
      query = capturedQuery(ApiEndpoints.ecomOrders);
      printTestLog('status → expected: "6", actual: "${query['status']}"');
      expect(query['status'], '6');
    });
  });

  group('getEcommerceOrderDetail', () {
    test('unwraps the single-element list the endpoint returns', () async {
      printTestDivider('getEcommerceOrderDetail unwraps the single-element list the endpoint returns');
      stubGet(ApiEndpoints.ecomOrders, fixture('ecommerce_order_detail'));

      final item = await repository.getEcommerceOrderDetail('413');

      verify(
        () => mockApiClient.get(
          ApiEndpoints.ecomOrders,
          queryParameters: {ApiParameters.orderItemId: '413'},
        ),
      ).called(1);
      printTestLog('id → expected: non-null, actual: ${item.id}');
      expect(item.id, isNotNull);
    });

    test('accepts a bare object as well as a list', () async {
      printTestDivider('getEcommerceOrderDetail accepts a bare object as well as a list');
      stubGet(ApiEndpoints.ecomOrders, {
        'status': 1,
        'data': {'id': 413, 'product_name': 'Test'},
      });

      final item = await repository.getEcommerceOrderDetail('413');

      printTestLog('id → expected: 413, actual: ${item.id}');
      expect(item.id, 413);
    });

    test('throws when the response carries no item', () async {
      printTestDivider('getEcommerceOrderDetail throws when the response carries no item');
      stubGet(ApiEndpoints.ecomOrders, {'status': 1, 'data': []});

      printTestLog('expected: throws ApiException, actual: calling now...');
      expect(
        repository.getEcommerceOrderDetail('999'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('mutations', () {
    test('updateOrderStatus sends the id and status, omitting a null OTP', () async {
      printTestDivider('updateOrderStatus sends the id and status, omitting a null OTP');
      when(
        () => mockApiClient.post(ApiEndpoints.updateStatus, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': 1});

      await repository.updateOrderStatus(orderId: '6', orderStatus: '5');

      final captured = verify(
        () => mockApiClient.post(
          ApiEndpoints.updateStatus,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;

      printTestLog('orderId → expected: "6", actual: "${captured[ApiParameters.orderId]}"');
      expect(captured[ApiParameters.orderId], '6');
      printTestLog('statusId → expected: "5", actual: "${captured[ApiParameters.statusId]}"');
      expect(captured[ApiParameters.statusId], '5');
      // The null-aware spread drops the OTP key entirely rather than sending null.
      printTestLog('otp present → expected: false, actual: ${captured.containsKey(ApiParameters.otp)}');
      expect(captured.containsKey(ApiParameters.otp), isFalse);
    });

    test('updateOrderStatus includes the OTP when delivering', () async {
      printTestDivider('updateOrderStatus includes the OTP when delivering');
      when(
        () => mockApiClient.post(ApiEndpoints.updateStatus, data: any(named: 'data')),
      ).thenAnswer((_) async => {'status': 1});

      await repository.updateOrderStatus(
        orderId: '6',
        orderStatus: '6',
        otp: '576400',
      );

      final captured = verify(
        () => mockApiClient.post(
          ApiEndpoints.updateStatus,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;

      printTestLog('otp → expected: "576400", actual: "${captured[ApiParameters.otp]}"');
      expect(captured[ApiParameters.otp], '576400');
    });

    test('updateReturnRequestOrderStatus sends the request id and status', () async {
      printTestDivider('updateReturnRequestOrderStatus sends the request id and status');
      when(
        () => mockApiClient.post(
          ApiEndpoints.returnRequestStatusUpdate,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.updateReturnRequestOrderStatus(
        returnRequestId: '23',
        orderStatus: '7',
      );

      verify(
        () => mockApiClient.post(
          ApiEndpoints.returnRequestStatusUpdate,
          data: {ApiParameters.id: '23', ApiParameters.status: '7'},
        ),
      ).called(1);
    });

    test('orderLiveTracking sends the coordinates', () async {
      printTestDivider('orderLiveTracking sends the coordinates');
      when(
        () => mockApiClient.post(
          ApiEndpoints.manageLiveTracking,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      await repository.orderLiveTracking(
        orderId: '6',
        orderStatus: '5',
        latitude: '19.076',
        longitude: '72.8777',
      );

      verify(
        () => mockApiClient.post(
          ApiEndpoints.manageLiveTracking,
          data: {
            ApiParameters.orderId: '6',
            ApiParameters.orderStatus: '5',
            ApiParameters.latitude: '19.076',
            ApiParameters.longitude: '72.8777',
          },
        ),
      ).called(1);
    });
  });
}
