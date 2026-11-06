import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/services/analytics_service.dart';
import 'package:deliveryboy/core/services/crashlytics_service.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef ReturnRequestOrderStatusUpdateState = AsyncState<()>;
typedef ReturnRequestOrderStatusUpdateInitial = AsyncInitial<()>;
typedef ReturnRequestOrderStatusUpdating = AsyncLoading<()>;
typedef ReturnRequestOrderStatusUpdateLoaded = AsyncLoaded<()>;
typedef ReturnRequestOrderStatusUpdateError = AsyncError<()>;

/// Updates a return request's status (e.g. picked up, received) and logs the change.
class ReturnRequestOrderStatusUpdateCubit extends BaseAsyncCubit<()> {
  final OrderRepository _repository;

  ReturnRequestOrderStatusUpdateCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Submits the new [orderStatus] for [returnRequestId].
  Future<void> updateReturnRequestOrderStatus({
    required String returnRequestId,
    required String orderStatus,
  }) => run(
    () async {
      await _repository.updateReturnRequestOrderStatus(
        returnRequestId: returnRequestId,
        orderStatus: orderStatus,
      );
      return ();
    },
    onSuccess: (_) => AnalyticsService.instance.logEvent(
      AppConstants.eventReturnOrderStatusUpdate,
      parameters: {
        AppConstants.paramReturnRequestId: returnRequestId,
        AppConstants.paramOrderStatus: orderStatus,
      },
    ),
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'updateReturnRequestOrderStatus failed',
    ),
  );
}
