import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../models/return_order_model.dart';
import '../repositories/order_repository.dart';

/// Active filter params for the return-orders list.
typedef ReturnOrderFilters = ({
  String status,
  String search,
  String? startDate,
  String? endDate,
});

const _kEmptyReturnOrderFilters = (
  status: '',
  search: '',
  startDate: null,
  endDate: null,
);

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Paginated list of return orders, filterable by status, search text, and date range.
class ReturnOrderCubit
    extends FilteredPaginationCubit<ReturnRequestData, ReturnOrderFilters> {
  final OrderRepository _repository;

  ReturnOrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(_kEmptyReturnOrderFilters);

  String get selectedStatus => currentFilters.status;
  String get search => currentFilters.search;
  String? get startDate => currentFilters.startDate;
  String? get endDate => currentFilters.endDate;

  /// Builds the paginated fetcher for the current [filters].
  @override
  PaginationFetcher<ReturnRequestData> buildFetcher(
    ReturnOrderFilters filters,
  ) => (offset) => _repository.getReturnOrders(
    status: filters.status,
    search: filters.search,
    startDate: filters.startDate,
    endDate: filters.endDate,
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
  Future<void> clearFilters() => applyFilters(_kEmptyReturnOrderFilters);

  bool get hasActiveFilters =>
      selectedStatus.isNotEmpty ||
      search.isNotEmpty ||
      startDate != null ||
      endDate != null;
}
