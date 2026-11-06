import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef OrderStatusListState = AsyncState<List<OrderStatusData>>;
typedef OrderStatusListInitial = AsyncInitial<List<OrderStatusData>>;
typedef OrderStatusListLoading = AsyncLoading<List<OrderStatusData>>;
typedef OrderStatusListLoaded = AsyncLoaded<List<OrderStatusData>>;
typedef OrderStatusListError = AsyncError<List<OrderStatusData>>;

/// Loads quick-order status options, excluding cancelled/returned statuses.
class OrderStatusListCubit extends BaseAsyncCubit<List<OrderStatusData>> {
  final OrderRepository _repository;

  OrderStatusListCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the order status list for [channel], dropping statuses "7" and "8".
  Future<void> loadStatuses({String? channel}) => run(() async {
    final result = await _repository.getOrderStatuses(channel: channel);
    return (result.data ?? [])
        .where((s) => s.id != "8" && s.id != "7")
        .toList();
  });
}
