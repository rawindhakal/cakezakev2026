import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef ReturnOrderStatusListState = AsyncState<List<OrderStatusData>>;
typedef ReturnOrderStatusListInitial = AsyncInitial<List<OrderStatusData>>;
typedef ReturnOrderStatusListLoading = AsyncLoading<List<OrderStatusData>>;
typedef ReturnOrderStatusListLoaded = AsyncLoaded<List<OrderStatusData>>;
typedef ReturnOrderStatusListError = AsyncError<List<OrderStatusData>>;

/// Loads the return-order status options used to populate status chips/filters.
class ReturnOrderStatusListCubit extends BaseAsyncCubit<List<OrderStatusData>> {
  final OrderRepository _repository;

  ReturnOrderStatusListCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the return-order status list.
  Future<void> loadStatuses() => run(() async {
    final result = await _repository.getOrderStatuses();
    return result.returnStatuses ?? [];
  });
}
