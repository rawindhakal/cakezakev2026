import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import '../repositories/settlement_history_repositories.dart';

// ── Filters ──────────────────────────────────────────────────────────────────
typedef SettlementHistoryFilters = ({
  String search,
  String entryType,
  String? startDate,
  String? endDate,
});

const _emptySettlementHistoryFilters = (
  search: '',
  entryType: '',
  startDate: null,
  endDate: null,
);

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Manages the paginated fund transfer/settlement list with search and date-range filters.
class SettlementHistoryCubit
    extends
        FilteredPaginationCubit<
          SettlementHistoryData,
          SettlementHistoryFilters
        > {
  final SettlementHistoryRepository _repository;

  SettlementHistoryCubit({SettlementHistoryRepository? repository})
    : _repository = repository ?? SettlementHistoryRepository(),
      super(_emptySettlementHistoryFilters);

  String get search => currentFilters.search;
  String get entryType => currentFilters.entryType;
  String? get startDate => currentFilters.startDate;
  String? get endDate => currentFilters.endDate;

  @override
  PaginationFetcher<SettlementHistoryData> buildFetcher(
    SettlementHistoryFilters filters,
  ) => (offset) async {
    final result = await _repository.getSettlementHistorys(
      search: filters.search,
      entryType: filters.entryType,
      startDate: filters.startDate,
      endDate: filters.endDate,
      offset: offset,
    );
    return PaginatedResponse<SettlementHistoryData>(
      data: result.data ?? [],
      total: result.total ?? 0,
    );
  };

  // Backward-compatible aliases for existing call sites.
  /// Load the first page of fund transfers.
  Future<void> loadTransfers() => fetchInitial();

  /// Load the next page of fund transfers.
  Future<void> loadMore() => fetchMore();

  /// [search]/[entryType] merge with the current value when omitted.
  /// [startDate]/[endDate] are passed through as-is (including null, to clear
  /// the date range) — callers must pass the current value explicitly to
  /// keep it unchanged, matching [OrderCubit]'s date-filter convention.
  Future<void> updateFilters({
    String? search,
    String? entryType,
    String? startDate,
    String? endDate,
  }) => applyFilters((
    search: search ?? this.search,
    entryType: entryType ?? this.entryType,
    startDate: startDate,
    endDate: endDate,
  ));

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilters(_emptySettlementHistoryFilters);

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      entryType.isNotEmpty ||
      startDate != null ||
      endDate != null;
}
