import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef ReturnOrderStatusListFilterState = AsyncState<List<OrderStatusData>>;
typedef ReturnOrderStatusListFilterInitial =
    AsyncInitial<List<OrderStatusData>>;
typedef ReturnOrderStatusListFilterLoading =
    AsyncLoading<List<OrderStatusData>>;
typedef ReturnOrderStatusListFilterLoaded =
    AsyncLoaded<List<OrderStatusData>>;
typedef ReturnOrderStatusListFilterError = AsyncError<List<OrderStatusData>>;

/// Loads return-order status options (with a prepended "All" entry) for the filter sheet.
class ReturnOrderStatusListFilterCubit
    extends BaseAsyncCubit<List<OrderStatusData>> {
  final OrderRepository _repository;

  ReturnOrderStatusListFilterCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the return-order status list, inserting an "All" option at the top.
  Future<void> returnOrderStatusesFilter() => run(() async {
    final result = await _repository.getOrderStatuses();
    final statuses = (result.returnStatuses ?? []).toList();
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
