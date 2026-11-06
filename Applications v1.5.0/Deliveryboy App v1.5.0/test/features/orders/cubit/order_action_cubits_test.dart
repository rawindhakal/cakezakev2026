import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_detail_cubit.dart';
// Prefixed because order_live_tracking_cubit.dart declares its loading state
// as `OrderStatusUpdating` too — the same name order_status_update_cubit.dart
// uses, so the two clash on a plain import. (Looks like a copy-paste in the
// prod typedef: the tracking cubit's loading state would read better as
// `OrderLiveTrackingLoading`.)
import 'package:deliveryboy/features/orders/cubit/order_live_tracking_cubit.dart'
    as tracking;
import 'package:deliveryboy/features/orders/cubit/order_status_update_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_request_order_status_update_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';

import '../../../helpers/mock_order_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockOrderRepository repository;

  setUp(() => repository = MockOrderRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('OrderDetailCubit', () {
    blocTest<OrderDetailCubit, OrderDetailState>(
      'emits [Loading, Loaded] with the order detail',
      setUp: () {
        printTestDivider('OrderDetailCubit emits [Loading, Loaded] with the order detail');
        when(() => repository.getOrderById(any())).thenAnswer(
          (_) async => OrderDetail(
            data: OrderDetailData.fromJson(const {'id': 187}),
          ),
        );
      },
      build: () => OrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadOrder('187'),
      expect: () => [isA<OrderDetailLoading>(), isA<OrderDetailLoaded>()],
      verify: (_) => verify(() => repository.getOrderById('187')).called(1),
    );

    blocTest<OrderDetailCubit, OrderDetailState>(
      'errors when the response carries no order',
      setUp: () {
        printTestDivider('OrderDetailCubit errors when the response carries no order');
        // A 200 with an empty data block means the id no longer resolves —
        // surfaced as "order not found" rather than a blank detail screen.
        when(
          () => repository.getOrderById(any()),
        ).thenAnswer((_) async => OrderDetail());
      },
      build: () => OrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadOrder('999'),
      expect: () => [
        isA<OrderDetailLoading>(),
        isA<OrderDetailError>().having(
          (s) => s.message,
          'message is a non-empty not-found message',
          isNotEmpty,
        ),
      ],
    );

    blocTest<OrderDetailCubit, OrderDetailState>(
      'emits [Loading, Error] carrying the API message',
      setUp: () {
        printTestDivider('OrderDetailCubit emits [Loading, Error] carrying the API message');
        when(
          () => repository.getOrderById(any()),
        ).thenThrow(const ApiException(message: 'Order unavailable'));
      },
      build: () => OrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadOrder('187'),
      expect: () => [
        isA<OrderDetailLoading>(),
        isA<OrderDetailError>().having(
          (s) => s.message,
          'message',
          'Order unavailable',
        ),
      ],
    );
  });

  group('EcommerceOrderDetailCubit', () {
    blocTest<EcommerceOrderDetailCubit, EcommerceOrderDetailState>(
      'emits [Loading, Loaded] for the order item',
      setUp: () {
        printTestDivider('EcommerceOrderDetailCubit emits [Loading, Loaded] for the order item');
        when(() => repository.getEcommerceOrderDetail(any())).thenAnswer(
          (_) async => EcommerceOrderDataModel.fromJson(const {'id': 42}),
        );
      },
      build: () => EcommerceOrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadOrderDetail('42'),
      expect: () => [
        isA<EcommerceOrderDetailLoading>(),
        isA<EcommerceOrderDetailLoaded>(),
      ],
      verify: (_) =>
          verify(() => repository.getEcommerceOrderDetail('42')).called(1),
    );

    blocTest<EcommerceOrderDetailCubit, EcommerceOrderDetailState>(
      'emits [Loading, Error] on failure',
      setUp: () {
        printTestDivider('EcommerceOrderDetailCubit emits [Loading, Error] on failure');
        when(
          () => repository.getEcommerceOrderDetail(any()),
        ).thenThrow(const ApiException(message: 'Item unavailable'));
      },
      build: () => EcommerceOrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadOrderDetail('42'),
      expect: () => [
        isA<EcommerceOrderDetailLoading>(),
        isA<EcommerceOrderDetailError>().having(
          (s) => s.message,
          'message',
          'Item unavailable',
        ),
      ],
    );
  });

  group('ReturnOrderDetailCubit', () {
    blocTest<ReturnOrderDetailCubit, ReturnOrderDetailState>(
      'emits [Loading, Loaded] with the return request',
      setUp: () {
        printTestDivider('ReturnOrderDetailCubit emits [Loading, Loaded] with the return request');
        when(() => repository.getReturnRequestById(any())).thenAnswer(
          (_) async => ReturnDetailResponse(
            data: ReturnRequestData.fromJson(const {'id': 7}),
          ),
        );
      },
      build: () => ReturnOrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadDetail('7'),
      expect: () => [
        isA<ReturnOrderDetailLoading>(),
        isA<ReturnOrderDetailLoaded>(),
      ],
      verify: (_) => verify(() => repository.getReturnRequestById('7')).called(1),
    );

    blocTest<ReturnOrderDetailCubit, ReturnOrderDetailState>(
      'errors when the response carries no return request',
      setUp: () {
        printTestDivider('ReturnOrderDetailCubit errors when the response carries no return request');
        when(
          () => repository.getReturnRequestById(any()),
        ).thenAnswer((_) async => ReturnDetailResponse());
      },
      build: () => ReturnOrderDetailCubit(repository: repository),
      act: (cubit) => cubit.loadDetail('999'),
      expect: () => [
        isA<ReturnOrderDetailLoading>(),
        isA<ReturnOrderDetailError>().having(
          (s) => s.message,
          'message is a non-empty not-found message',
          isNotEmpty,
        ),
      ],
    );
  });

  group('OrderStatusUpdateCubit', () {
    blocTest<OrderStatusUpdateCubit, OrderStatusUpdateState>(
      'submits the new status and emits [Loading, Loaded]',
      setUp: () {
        printTestDivider('OrderStatusUpdateCubit submits the new status and emits [Loading, Loaded]');
        when(
          () => repository.updateOrderStatus(
            orderId: any(named: 'orderId'),
            orderStatus: any(named: 'orderStatus'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => OrderStatusUpdateCubit(repository: repository),
      act: (cubit) => cubit.updateStatus(orderId: '187', orderStatus: '5'),
      expect: () => [isA<OrderStatusUpdating>(), isA<OrderStatusUpdateLoaded>()],
      verify: (_) => verify(
        () => repository.updateOrderStatus(
          orderId: '187',
          orderStatus: '5',
          otp: null,
        ),
      ).called(1),
    );

    blocTest<OrderStatusUpdateCubit, OrderStatusUpdateState>(
      'passes the delivery OTP through when one is given',
      setUp: () {
        printTestDivider('OrderStatusUpdateCubit passes the delivery OTP through when one is given');
        when(
          () => repository.updateOrderStatus(
            orderId: any(named: 'orderId'),
            orderStatus: any(named: 'orderStatus'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => OrderStatusUpdateCubit(repository: repository),
      act: (cubit) =>
          cubit.updateStatus(orderId: '187', orderStatus: '6', otp: '4321'),
      verify: (_) => verify(
        () => repository.updateOrderStatus(
          orderId: '187',
          orderStatus: '6',
          otp: '4321',
        ),
      ).called(1),
    );

    blocTest<OrderStatusUpdateCubit, OrderStatusUpdateState>(
      'emits [Loading, Error] carrying the API message',
      setUp: () {
        printTestDivider('OrderStatusUpdateCubit emits [Loading, Error] carrying the API message');
        when(
          () => repository.updateOrderStatus(
            orderId: any(named: 'orderId'),
            orderStatus: any(named: 'orderStatus'),
            otp: any(named: 'otp'),
          ),
        ).thenThrow(const ApiException(message: 'Invalid OTP'));
      },
      build: () => OrderStatusUpdateCubit(repository: repository),
      act: (cubit) =>
          cubit.updateStatus(orderId: '187', orderStatus: '6', otp: '0000'),
      expect: () => [
        isA<OrderStatusUpdating>(),
        isA<OrderStatusUpdateError>().having(
          (s) => s.message,
          'message',
          'Invalid OTP',
        ),
      ],
    );
  });

  group('ReturnRequestOrderStatusUpdateCubit', () {
    blocTest<ReturnRequestOrderStatusUpdateCubit, ReturnRequestOrderStatusUpdateState>(
      'submits the new return status and emits [Loading, Loaded]',
      setUp: () {
        printTestDivider(
          'ReturnRequestOrderStatusUpdateCubit submits the new return status and emits [Loading, Loaded]',
        );
        when(
          () => repository.updateReturnRequestOrderStatus(
            returnRequestId: any(named: 'returnRequestId'),
            orderStatus: any(named: 'orderStatus'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => ReturnRequestOrderStatusUpdateCubit(repository: repository),
      act: (cubit) => cubit.updateReturnRequestOrderStatus(
        returnRequestId: '7',
        orderStatus: '11',
      ),
      expect: () => [
        isA<ReturnRequestOrderStatusUpdating>(),
        isA<ReturnRequestOrderStatusUpdateLoaded>(),
      ],
      verify: (_) => verify(
        () => repository.updateReturnRequestOrderStatus(
          returnRequestId: '7',
          orderStatus: '11',
        ),
      ).called(1),
    );

    blocTest<ReturnRequestOrderStatusUpdateCubit, ReturnRequestOrderStatusUpdateState>(
      'emits [Loading, Error] on failure',
      setUp: () {
        printTestDivider('ReturnRequestOrderStatusUpdateCubit emits [Loading, Error] on failure');
        when(
          () => repository.updateReturnRequestOrderStatus(
            returnRequestId: any(named: 'returnRequestId'),
            orderStatus: any(named: 'orderStatus'),
          ),
        ).thenThrow(const ApiException(message: 'Cannot update return'));
      },
      build: () => ReturnRequestOrderStatusUpdateCubit(repository: repository),
      act: (cubit) => cubit.updateReturnRequestOrderStatus(
        returnRequestId: '7',
        orderStatus: '11',
      ),
      expect: () => [
        isA<ReturnRequestOrderStatusUpdating>(),
        isA<ReturnRequestOrderStatusUpdateError>().having(
          (s) => s.message,
          'message',
          'Cannot update return',
        ),
      ],
    );
  });

  group('OrderLiveTrackingCubit', () {
    blocTest<tracking.OrderLiveTrackingCubit, tracking.OrderLiveTrackingState>(
      'pushes the current coordinates for the order',
      setUp: () {
        printTestDivider('OrderLiveTrackingCubit pushes the current coordinates for the order');
        when(
          () => repository.orderLiveTracking(
            orderId: any(named: 'orderId'),
            orderStatus: any(named: 'orderStatus'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => tracking.OrderLiveTrackingCubit(repository: repository),
      act: (cubit) => cubit.orderLiveTracking(
        orderId: '187',
        orderStatus: '5',
        latitude: '19.0760',
        longitude: '72.8777',
      ),
      expect: () => [
        isA<tracking.OrderStatusUpdating>(),
        isA<tracking.OrderLiveTrackingLoaded>(),
      ],
      verify: (_) => verify(
        () => repository.orderLiveTracking(
          orderId: '187',
          orderStatus: '5',
          latitude: '19.0760',
          longitude: '72.8777',
        ),
      ).called(1),
    );

    blocTest<tracking.OrderLiveTrackingCubit, tracking.OrderLiveTrackingState>(
      'emits [Loading, Error] when the ping fails',
      setUp: () {
        printTestDivider('OrderLiveTrackingCubit emits [Loading, Error] when the ping fails');
        when(
          () => repository.orderLiveTracking(
            orderId: any(named: 'orderId'),
            orderStatus: any(named: 'orderStatus'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        ).thenThrow(const ApiException(message: 'Tracking unavailable'));
      },
      build: () => tracking.OrderLiveTrackingCubit(repository: repository),
      act: (cubit) => cubit.orderLiveTracking(
        orderId: '187',
        orderStatus: '5',
        latitude: '19.0760',
        longitude: '72.8777',
      ),
      expect: () => [
        isA<tracking.OrderStatusUpdating>(),
        isA<tracking.OrderLiveTrackingError>().having(
          (s) => s.message,
          'message',
          'Tracking unavailable',
        ),
      ],
    );
  });
}
