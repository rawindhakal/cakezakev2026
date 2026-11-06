import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';

import '../../../helpers/mock_order_repository.dart';
import '../../../helpers/test_logging.dart';

/// The four status-list cubits all call the same `getOrderStatuses` endpoint
/// and differ only in how they post-process it — which is exactly what these
/// tests pin down.
void main() {
  late MockOrderRepository repository;

  setUp(() => repository = MockOrderRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  OrderStatusData status(String id, String name) =>
      OrderStatusData(id: id, status: name, statusName: name);

  void stubStatuses({
    List<OrderStatusData>? data,
    List<OrderStatusData>? returnStatuses,
  }) {
    when(
      () => repository.getOrderStatuses(channel: any(named: 'channel')),
    ).thenAnswer(
      (_) async => OrderStatus(data: data, returnStatuses: returnStatuses),
    );
  }

  void stubFailure() {
    when(
      () => repository.getOrderStatuses(channel: any(named: 'channel')),
    ).thenThrow(const ApiException(message: 'Statuses unavailable'));
  }

  group('OrderStatusListCubit', () {
    blocTest<OrderStatusListCubit, OrderStatusListState>(
      'drops the statuses a rider must never set by hand',
      setUp: () {
        printTestDivider(
          'OrderStatusListCubit drops the statuses a rider must never set by hand',
        );
        // Ids 7 and 8 are backend-only transitions (returned/cancelled) and
        // must not appear in the rider's status picker.
        stubStatuses(
          data: [
            status('5', 'Out For Delivery'),
            status('7', 'Returned'),
            status('8', 'Cancelled'),
            status('6', 'Delivered'),
          ],
        );
      },
      build: () => OrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(),
      expect: () => [
        isA<OrderStatusListLoading>(),
        isA<OrderStatusListLoaded>().having(
          (s) => s.data.map((e) => e.id).toList(),
          'ids',
          ['5', '6'],
        ),
      ],
    );

    blocTest<OrderStatusListCubit, OrderStatusListState>(
      'forwards the channel to the repository',
      setUp: () {
        printTestDivider('OrderStatusListCubit forwards the channel to the repository');
        stubStatuses(data: [status('5', 'Out For Delivery')]);
      },
      build: () => OrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(channel: 'ecommerce'),
      verify: (_) => verify(
        () => repository.getOrderStatuses(channel: 'ecommerce'),
      ).called(1),
    );

    blocTest<OrderStatusListCubit, OrderStatusListState>(
      'emits an empty list when the response carries no statuses',
      setUp: () {
        printTestDivider(
          'OrderStatusListCubit emits an empty list when the response carries no statuses',
        );
        stubStatuses();
      },
      build: () => OrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(),
      expect: () => [
        isA<OrderStatusListLoading>(),
        isA<OrderStatusListLoaded>().having((s) => s.data, 'data', isEmpty),
      ],
    );

    blocTest<OrderStatusListCubit, OrderStatusListState>(
      'emits [Loading, Error] on failure',
      setUp: () {
        printTestDivider('OrderStatusListCubit emits [Loading, Error] on failure');
        stubFailure();
      },
      build: () => OrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(),
      expect: () => [
        isA<OrderStatusListLoading>(),
        isA<OrderStatusListError>().having(
          (s) => s.message,
          'message',
          'Statuses unavailable',
        ),
      ],
    );
  });

  group('OrderStatusListFilterCubit', () {
    blocTest<OrderStatusListFilterCubit, OrderStatusListFilterState>(
      'prepends an All entry for the filter sheet',
      setUp: () {
        printTestDivider('OrderStatusListFilterCubit prepends an All entry for the filter sheet');
        stubStatuses(
          data: [status('5', 'Out For Delivery'), status('6', 'Delivered')],
        );
      },
      build: () => OrderStatusListFilterCubit(repository: repository),
      act: (cubit) => cubit.orderStatusesFilter(),
      expect: () => [
        isA<OrderStatusListFilterLoading>(),
        isA<OrderStatusListFilterLoaded>()
            // The All entry carries an empty id, which the list cubits treat
            // as "no status filter".
            .having((s) => s.data.first.id, 'first id', '')
            .having((s) => s.data.first.status, 'first status', 'All')
            .having((s) => s.data.length, 'length', 3),
      ],
    );

    blocTest<OrderStatusListFilterCubit, OrderStatusListFilterState>(
      'keeps the backend-only statuses that the picker hides',
      setUp: () {
        printTestDivider(
          'OrderStatusListFilterCubit keeps the backend-only statuses that the picker hides',
        );
        // Filtering by a status the rider can't *set* is still valid, so this
        // cubit deliberately does not apply OrderStatusListCubit's 7/8 filter.
        stubStatuses(data: [status('7', 'Returned'), status('8', 'Cancelled')]);
      },
      build: () => OrderStatusListFilterCubit(repository: repository),
      act: (cubit) => cubit.orderStatusesFilter(),
      expect: () => [
        isA<OrderStatusListFilterLoading>(),
        isA<OrderStatusListFilterLoaded>().having(
          (s) => s.data.map((e) => e.id).toList(),
          'ids',
          ['', '7', '8'],
        ),
      ],
    );

    blocTest<OrderStatusListFilterCubit, OrderStatusListFilterState>(
      'still offers All when the response carries no statuses',
      setUp: () {
        printTestDivider(
          'OrderStatusListFilterCubit still offers All when the response carries no statuses',
        );
        stubStatuses();
      },
      build: () => OrderStatusListFilterCubit(repository: repository),
      act: (cubit) => cubit.orderStatusesFilter(),
      expect: () => [
        isA<OrderStatusListFilterLoading>(),
        isA<OrderStatusListFilterLoaded>().having((s) => s.data.length, 'length', 1),
      ],
    );

    blocTest<OrderStatusListFilterCubit, OrderStatusListFilterState>(
      'emits [Loading, Error] on failure',
      setUp: () {
        printTestDivider('OrderStatusListFilterCubit emits [Loading, Error] on failure');
        stubFailure();
      },
      build: () => OrderStatusListFilterCubit(repository: repository),
      act: (cubit) => cubit.orderStatusesFilter(),
      expect: () => [
        isA<OrderStatusListFilterLoading>(),
        isA<OrderStatusListFilterError>().having(
          (s) => s.message,
          'message',
          'Statuses unavailable',
        ),
      ],
    );
  });

  group('ReturnOrderStatusListCubit', () {
    blocTest<ReturnOrderStatusListCubit, ReturnOrderStatusListState>(
      'reads the return statuses, not the order ones',
      setUp: () {
        printTestDivider('ReturnOrderStatusListCubit reads the return statuses, not the order ones');
        stubStatuses(
          data: [status('5', 'Out For Delivery')],
          returnStatuses: [status('11', 'Return to Store')],
        );
      },
      build: () => ReturnOrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(),
      expect: () => [
        isA<ReturnOrderStatusListLoading>(),
        isA<ReturnOrderStatusListLoaded>().having(
          (s) => s.data.map((e) => e.id).toList(),
          'ids',
          ['11'],
        ),
      ],
    );

    blocTest<ReturnOrderStatusListCubit, ReturnOrderStatusListState>(
      'emits an empty list when there are no return statuses',
      setUp: () {
        printTestDivider(
          'ReturnOrderStatusListCubit emits an empty list when there are no return statuses',
        );
        stubStatuses(data: [status('5', 'Out For Delivery')]);
      },
      build: () => ReturnOrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(),
      expect: () => [
        isA<ReturnOrderStatusListLoading>(),
        isA<ReturnOrderStatusListLoaded>().having((s) => s.data, 'data', isEmpty),
      ],
    );

    blocTest<ReturnOrderStatusListCubit, ReturnOrderStatusListState>(
      'emits [Loading, Error] on failure',
      setUp: () {
        printTestDivider('ReturnOrderStatusListCubit emits [Loading, Error] on failure');
        stubFailure();
      },
      build: () => ReturnOrderStatusListCubit(repository: repository),
      act: (cubit) => cubit.loadStatuses(),
      expect: () => [
        isA<ReturnOrderStatusListLoading>(),
        isA<ReturnOrderStatusListError>(),
      ],
    );
  });

  group('ReturnOrderStatusListFilterCubit', () {
    blocTest<ReturnOrderStatusListFilterCubit, ReturnOrderStatusListFilterState>(
      'prepends All to the return statuses',
      setUp: () {
        printTestDivider('ReturnOrderStatusListFilterCubit prepends All to the return statuses');
        stubStatuses(
          returnStatuses: [
            status('11', 'Return to Store'),
            status('12', 'Received'),
          ],
        );
      },
      build: () => ReturnOrderStatusListFilterCubit(repository: repository),
      act: (cubit) => cubit.returnOrderStatusesFilter(),
      expect: () => [
        isA<ReturnOrderStatusListFilterLoading>(),
        isA<ReturnOrderStatusListFilterLoaded>()
            .having((s) => s.data.first.id, 'first id', '')
            .having((s) => s.data.map((e) => e.id).toList(), 'ids', ['', '11', '12']),
      ],
    );

    // A plain test, not blocTest: this one drives the cubit twice, and
    // blocTest's `verify` callback runs after the cubit has been closed.
    test('does not stack up a second All entry when loaded twice', () async {
      printTestDivider('does not stack up a second All entry when loaded twice');
      stubStatuses(returnStatuses: [status('11', 'Return to Store')]);
      final cubit = ReturnOrderStatusListFilterCubit(repository: repository);

      await cubit.returnOrderStatusesFilter();
      await cubit.returnOrderStatusesFilter();

      final data = (cubit.state as ReturnOrderStatusListFilterLoaded).data;
      printTestLog('ids after a second load → expected: ["", "11"], actual: ${data.map((e) => e.id).toList()}');
      expect(data.map((e) => e.id).toList(), ['', '11']);
      await cubit.close();
    });

    blocTest<ReturnOrderStatusListFilterCubit, ReturnOrderStatusListFilterState>(
      'emits [Loading, Error] on failure',
      setUp: () {
        printTestDivider('ReturnOrderStatusListFilterCubit emits [Loading, Error] on failure');
        stubFailure();
      },
      build: () => ReturnOrderStatusListFilterCubit(repository: repository),
      act: (cubit) => cubit.returnOrderStatusesFilter(),
      expect: () => [
        isA<ReturnOrderStatusListFilterLoading>(),
        isA<ReturnOrderStatusListFilterError>(),
      ],
    );
  });
}
