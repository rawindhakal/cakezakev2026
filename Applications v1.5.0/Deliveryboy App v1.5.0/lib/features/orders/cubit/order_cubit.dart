import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

/// Active filter params for the quick-orders list.
typedef OrderFilters = ({
  String status,
  String search,
  String? startDate,
  String? endDate,
});

const _kEmptyOrderFilters = (
  status: '',
  search: '',
  startDate: null,
  endDate: null,
);

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Paginated list of quick orders, filterable by status, search text, and date range.
class OrderCubit extends FilteredPaginationCubit<OrderData, OrderFilters> {
  final OrderRepository _repository;

  OrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(_kEmptyOrderFilters);

  String get selectedStatus => currentFilters.status;
  String get search => currentFilters.search;
  String? get startDate => currentFilters.startDate;
  String? get endDate => currentFilters.endDate;

  /// Builds the paginated fetcher for the current [filters].
  @override
  PaginationFetcher<OrderData> buildFetcher(OrderFilters filters) =>
      (offset) => _repository.getOrders(
        status: filters.status,
        search: filters.search,
        startDeliveryDate: filters.startDate,
        endDeliveryDate: filters.endDate,
        offset: offset,
      );

  // Backward-compatible aliases for existing call sites.
  Future<void> loadOrders() => fetchInitial();

  Future<void> loadMore() => fetchMore();

  /// Apply filters and reload from the first page.
  Future<void> updateFilters({
    String? status,
    String? search,
    String? startDate,
    String? endDate,
  }) {
    return applyFilters((
      status: status ?? '',
      search: search ?? '',
      startDate: startDate,
      endDate: endDate,
    ));
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilters(_kEmptyOrderFilters);

  bool get hasActiveFilters =>
      selectedStatus.isNotEmpty ||
      search.isNotEmpty ||
      startDate != null ||
      endDate != null;
}
