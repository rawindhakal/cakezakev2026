import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef OrderStatusListFilterState = AsyncState<List<OrderStatusData>>;
typedef OrderStatusListFilterInitial = AsyncInitial<List<OrderStatusData>>;
typedef OrderStatusListFilterLoading = AsyncLoading<List<OrderStatusData>>;
typedef OrderStatusListFilterLoaded = AsyncLoaded<List<OrderStatusData>>;
typedef OrderStatusListFilterError = AsyncError<List<OrderStatusData>>;

/// Loads quick-order status options (with a prepended "All" entry) for the filter sheet.
class OrderStatusListFilterCubit extends BaseAsyncCubit<List<OrderStatusData>> {
  final OrderRepository _repository;

  OrderStatusListFilterCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the order status list for [channel], inserting an "All" option at the top.
  Future<void> orderStatusesFilter({String? channel}) => run(() async {
    final result = await _repository.getOrderStatuses(channel: channel);
    final statuses = (result.data ?? []).toList();
    statuses.insert(
      0,
      OrderStatusData(
        id: "",
        status: "All",
        statusName: LocalizationService.instance.translate(
          LanguageLabelKeys.all,
        ),
      ),
    );
    return statuses;
  });
}
