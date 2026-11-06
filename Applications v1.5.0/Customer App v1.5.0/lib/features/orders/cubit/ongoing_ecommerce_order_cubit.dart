import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import '../models/ecommerce_order_model.dart';
import '../repositories/order_repository.dart';

/// Filter params for ongoing/completed ecommerce order pagination (date range).
class EcommerceOrderFilter {
  final String? startDate;
  final String? endDate;

  const EcommerceOrderFilter({this.startDate, this.endDate});
}

class OngoingEcommerceOrderCubit
    extends
        FilteredPaginationCubit<EcommerceOrderDataModel, EcommerceOrderFilter> {
  final OrderRepository _repository;

  OngoingEcommerceOrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(const EcommerceOrderFilter());

  @override
  PaginationFetcher<EcommerceOrderDataModel> buildFetcher(
    EcommerceOrderFilter filters,
  ) {
    return (offset) async {
      final result = await _repository.getEcommerceOngoingOrders(
        offset: offset,
        startDate: filters.startDate,
        endDate: filters.endDate,
      );
      return PaginatedResponse(
        data: result.data ?? [],
        total: result.total ?? 0,
      );
    };
  }

  /// Drops a cancelled item from the ongoing list locally — no refetch.
  void removeOrder(int? orderItemId) {
    final current = state;
    if (current is! PaginationLoaded<EcommerceOrderDataModel>) return;
    final orders = current.data.where((o) => o.id != orderItemId).toList();
    if (orders.length == current.data.length) return;
    emit(
      current.copyWith(
        data: orders,
        total: current.total > 0 ? current.total - 1 : 0,
      ),
    );
  }
}
