import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

/// Active filter params for the ecommerce-orders list.
typedef EcommerceOrderFilters = ({
  String status,
  String? startDate,
  String? endDate,
});

const _kEmptyEcommerceOrderFilters = (
  status: '',
  startDate: null,
  endDate: null,
);

/// Paginated list of ecommerce orders, filterable by status and date range.
class EcommerceOrderCubit
    extends
        FilteredPaginationCubit<
          EcommerceOrderDataModel,
          EcommerceOrderFilters
        > {
  final OrderRepository _repository;

  EcommerceOrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(_kEmptyEcommerceOrderFilters);

  String get selectedStatus => currentFilters.status;
  String? get startDate => currentFilters.startDate;
  String? get endDate => currentFilters.endDate;

  /// Builds the paginated fetcher for the current [filters].
  @override
  PaginationFetcher<EcommerceOrderDataModel> buildFetcher(
    EcommerceOrderFilters filters,
  ) => (offset) => _repository.getEcommerceOrders(
    offset: offset,
    startDate: filters.startDate,
    endDate: filters.endDate,
    status: filters.status.isEmpty ? null : filters.status,
  );

  // Backward-compatible aliases for existing call sites.
  Future<void> loadOrders({String? startDate, String? endDate}) {
    return applyFilters((
      status: selectedStatus,
      startDate: startDate,
      endDate: endDate,
    ));
  }

  Future<void> loadMore() => fetchMore();

  /// Apply filters and reload from the first page.
  Future<void> updateFilters({
    String? status,
    String? startDate,
    String? endDate,
  }) {
    return applyFilters((
      status: status ?? '',
      startDate: startDate,
      endDate: endDate,
    ));
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilters(_kEmptyEcommerceOrderFilters);

  bool get hasActiveFilters =>
      selectedStatus.isNotEmpty || startDate != null || endDate != null;
}
