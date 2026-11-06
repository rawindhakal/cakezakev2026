import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';

import '../../../helpers/mock_order_repository.dart';
import '../../../helpers/test_logging.dart';

/// The three list cubits are thin filter wrappers over the shared pagination
/// base (covered on its own in test/commons/cubit), so these tests focus on
/// what each one adds: which repository call it makes and what it passes.
void main() {
  late MockOrderRepository repository;

  setUp(() => repository = MockOrderRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('OrderCubit', () {
    PaginatedResponse<OrderData> page(List<OrderData> data, int total) =>
        PaginatedResponse(data: data, total: total);

    OrderData order(String id) => OrderData.fromJson({'id': id});

    void stubOrders({PaginatedResponse<OrderData>? response}) {
      when(
        () => repository.getOrders(
          status: any(named: 'status'),
          search: any(named: 'search'),
          startDeliveryDate: any(named: 'startDeliveryDate'),
          endDeliveryDate: any(named: 'endDeliveryDate'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => response ?? page([order('1')], 1));
    }

    test('loads the first page with empty filters', () async {
      printTestDivider('OrderCubit loads the first page with empty filters');
      stubOrders();
      final cubit = OrderCubit(repository: repository);

      await cubit.loadOrders();

      verify(
        () => repository.getOrders(
          status: '',
          search: '',
          startDeliveryDate: null,
          endDeliveryDate: null,
          offset: 0,
        ),
      ).called(1);
      printTestLog('state → expected: PaginationLoaded, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<PaginationLoaded<OrderData>>());
      await cubit.close();
    });

    test('applies filters and reloads from the first page', () async {
      printTestDivider('OrderCubit applies filters and reloads from the first page');
      stubOrders();
      final cubit = OrderCubit(repository: repository);

      await cubit.updateFilters(
        status: '5',
        search: 'SB-ORD',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      );

      verify(
        () => repository.getOrders(
          status: '5',
          search: 'SB-ORD',
          startDeliveryDate: '2026-08-01',
          endDeliveryDate: '2026-08-17',
          offset: 0,
        ),
      ).called(1);
      printTestLog('selectedStatus → expected: "5", actual: "${cubit.selectedStatus}"');
      expect(cubit.selectedStatus, '5');
      printTestLog('search → expected: "SB-ORD", actual: "${cubit.search}"');
      expect(cubit.search, 'SB-ORD');
      await cubit.close();
    });

    test('treats omitted filter values as cleared, not unchanged', () async {
      printTestDivider('OrderCubit treats omitted filter values as cleared, not unchanged');
      stubOrders();
      final cubit = OrderCubit(repository: repository);

      await cubit.updateFilters(status: '5', search: 'SB-ORD');
      // Calling again with only a status drops the previous search rather than
      // carrying it over.
      await cubit.updateFilters(status: '6');

      printTestLog('search → expected: "", actual: "${cubit.search}"');
      expect(cubit.search, '');
      printTestLog('selectedStatus → expected: "6", actual: "${cubit.selectedStatus}"');
      expect(cubit.selectedStatus, '6');
      await cubit.close();
    });

    test('clearFilters resets every filter', () async {
      printTestDivider('OrderCubit clearFilters resets every filter');
      stubOrders();
      final cubit = OrderCubit(repository: repository);

      await cubit.updateFilters(
        status: '5',
        search: 'SB-ORD',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      );
      printTestLog('hasActiveFilters → expected: true, actual: ${cubit.hasActiveFilters}');
      expect(cubit.hasActiveFilters, isTrue);

      await cubit.clearFilters();

      printTestLog('hasActiveFilters → expected: false, actual: ${cubit.hasActiveFilters}');
      expect(cubit.hasActiveFilters, isFalse);
      printTestLog('startDate → expected: null, actual: ${cubit.startDate}');
      expect(cubit.startDate, isNull);
      await cubit.close();
    });

    test('hasActiveFilters is true when only a date is set', () async {
      printTestDivider('OrderCubit hasActiveFilters is true when only a date is set');
      stubOrders();
      final cubit = OrderCubit(repository: repository);

      await cubit.updateFilters(startDate: '2026-08-01');

      printTestLog('hasActiveFilters → expected: true, actual: ${cubit.hasActiveFilters}');
      expect(cubit.hasActiveFilters, isTrue);
      await cubit.close();
    });

    test('pages with the active filters still applied', () async {
      printTestDivider('OrderCubit pages with the active filters still applied');
      stubOrders(response: page([order('1'), order('2')], 10));
      final cubit = OrderCubit(repository: repository);

      await cubit.updateFilters(status: '5');
      await cubit.loadMore();

      verify(
        () => repository.getOrders(
          status: '5',
          search: '',
          startDeliveryDate: null,
          endDeliveryDate: null,
          offset: 2,
        ),
      ).called(1);
      await cubit.close();
    });

    test('surfaces the API message when the list fails', () async {
      printTestDivider('OrderCubit surfaces the API message when the list fails');
      when(
        () => repository.getOrders(
          status: any(named: 'status'),
          search: any(named: 'search'),
          startDeliveryDate: any(named: 'startDeliveryDate'),
          endDeliveryDate: any(named: 'endDeliveryDate'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(const ApiException(message: 'Orders unavailable'));
      final cubit = OrderCubit(repository: repository);

      await cubit.loadOrders();

      final state = cubit.state as PaginationError<OrderData>;
      printTestLog('message → expected: "Orders unavailable", actual: "${state.message}"');
      expect(state.message, 'Orders unavailable');
      await cubit.close();
    });
  });

  group('EcommerceOrderCubit', () {
    void stubEcommerce() {
      when(
        () => repository.getEcommerceOrders(
          offset: any(named: 'offset'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          status: any(named: 'status'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          data: [EcommerceOrderDataModel.fromJson(const {'id': 1})],
          total: 1,
        ),
      );
    }

    test('sends a null status when none is selected', () async {
      printTestDivider('EcommerceOrderCubit sends a null status when none is selected');
      stubEcommerce();
      final cubit = EcommerceOrderCubit(repository: repository);

      await cubit.loadOrders();

      // An empty status means "all", which this endpoint expects as an
      // omitted parameter rather than an empty string.
      verify(
        () => repository.getEcommerceOrders(
          offset: 0,
          startDate: null,
          endDate: null,
          status: null,
        ),
      ).called(1);
      await cubit.close();
    });

    test('forwards a selected status and date range', () async {
      printTestDivider('EcommerceOrderCubit forwards a selected status and date range');
      stubEcommerce();
      final cubit = EcommerceOrderCubit(repository: repository);

      await cubit.updateFilters(
        status: '6',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      );

      verify(
        () => repository.getEcommerceOrders(
          offset: 0,
          startDate: '2026-08-01',
          endDate: '2026-08-17',
          status: '6',
        ),
      ).called(1);
      printTestLog('selectedStatus → expected: "6", actual: "${cubit.selectedStatus}"');
      expect(cubit.selectedStatus, '6');
      await cubit.close();
    });

    test('loadOrders keeps the selected status while changing dates', () async {
      printTestDivider('EcommerceOrderCubit loadOrders keeps the selected status while changing dates');
      stubEcommerce();
      final cubit = EcommerceOrderCubit(repository: repository);

      await cubit.updateFilters(status: '6');
      await cubit.loadOrders(startDate: '2026-08-01', endDate: '2026-08-17');

      printTestLog('selectedStatus → expected: "6", actual: "${cubit.selectedStatus}"');
      expect(cubit.selectedStatus, '6');
      verify(
        () => repository.getEcommerceOrders(
          offset: 0,
          startDate: '2026-08-01',
          endDate: '2026-08-17',
          status: '6',
        ),
      ).called(1);
      await cubit.close();
    });
  });

  group('ReturnOrderCubit', () {
    void stubReturns() {
      when(
        () => repository.getReturnOrders(
          status: any(named: 'status'),
          search: any(named: 'search'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          data: [ReturnRequestData.fromJson(const {'id': 1})],
          total: 1,
        ),
      );
    }

    test('loads the first page with empty filters', () async {
      printTestDivider('ReturnOrderCubit loads the first page with empty filters');
      stubReturns();
      final cubit = ReturnOrderCubit(repository: repository);

      await cubit.fetchInitial();

      verify(
        () => repository.getReturnOrders(
          status: '',
          search: '',
          startDate: null,
          endDate: null,
          offset: 0,
        ),
      ).called(1);
      await cubit.close();
    });

    test('applies filters and exposes them', () async {
      printTestDivider('ReturnOrderCubit applies filters and exposes them');
      stubReturns();
      final cubit = ReturnOrderCubit(repository: repository);

      await cubit.applyFilters((
        status: '11',
        search: 'RET',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      ));

      verify(
        () => repository.getReturnOrders(
          status: '11',
          search: 'RET',
          startDate: '2026-08-01',
          endDate: '2026-08-17',
          offset: 0,
        ),
      ).called(1);
      printTestLog('selectedStatus → expected: "11", actual: "${cubit.selectedStatus}"');
      expect(cubit.selectedStatus, '11');
      printTestLog('search → expected: "RET", actual: "${cubit.search}"');
      expect(cubit.search, 'RET');
      await cubit.close();
    });
  });
}
