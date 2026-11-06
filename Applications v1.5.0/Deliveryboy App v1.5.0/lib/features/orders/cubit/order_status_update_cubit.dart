import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/services/analytics_service.dart';
import 'package:deliveryboy/core/services/crashlytics_service.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef OrderStatusUpdateState = AsyncState<()>;
typedef OrderStatusUpdateInitial = AsyncInitial<()>;
typedef OrderStatusUpdating = AsyncLoading<()>;
typedef OrderStatusUpdateLoaded = AsyncLoaded<()>;
typedef OrderStatusUpdateError = AsyncError<()>;

/// Updates a quick order's status (e.g. picked up, delivered) and logs the change.
class OrderStatusUpdateCubit extends BaseAsyncCubit<()> {
  final OrderRepository _repository;

  OrderStatusUpdateCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Submits the new [orderStatus] (with optional delivery [otp]) for [orderId].
  Future<void> updateStatus({
    required String orderId,
    required String orderStatus,
    String? otp,
  }) => run(
    () async {
      await _repository.updateOrderStatus(
        orderId: orderId,
        orderStatus: orderStatus,
        otp: otp,
      );
      return ();
    },
    onSuccess: (_) => AnalyticsService.instance.logEvent(
      AppConstants.eventOrderStatusUpdate,
      parameters: {
        AppConstants.paramOrderId: orderId,
        AppConstants.paramOrderStatus: orderStatus,
      },
    ),
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'updateOrderStatus failed',
    ),
  );

  /// Submits the new [orderStatus] (with optional delivery [otp]) for an
  /// ecommerce [orderItemId].
  Future<void> updateItemStatus({
    required String orderItemId,
    required String orderStatus,
    String? otp,
  }) => run(
    () async {
      await _repository.updateOrderItemStatus(
        orderItemId: orderItemId,
        orderStatus: orderStatus,
        otp: otp,
      );
      return ();
    },
    onSuccess: (_) => AnalyticsService.instance.logEvent(
      AppConstants.eventOrderStatusUpdate,
      parameters: {
        AppConstants.paramOrderItemId: orderItemId,
        AppConstants.paramOrderStatus: orderStatus,
      },
    ),
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'updateOrderItemStatus failed',
    ),
  );
}
