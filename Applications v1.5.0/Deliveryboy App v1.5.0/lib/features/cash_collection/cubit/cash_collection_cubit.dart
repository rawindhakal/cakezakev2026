import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../models/cash_collection_model.dart';
import '../repositories/cash_collection_repositories.dart';

/// Re-exported so screens can keep using the previous state-type aliases.
typedef CashCollectionState = PaginationState<CashCollectionModel>;
typedef CashCollectionInitial = PaginationInitial<CashCollectionModel>;
typedef CashCollectionLoading = PaginationLoading<CashCollectionModel>;
typedef CashCollectionLoaded = PaginationLoaded<CashCollectionModel>;
typedef CashCollectionError = PaginationError<CashCollectionModel>;

/// Active filter params for the cash-collection list.
typedef CashCollectionFilters = ({
  String search,
  String? startDate,
  String? endDate,
});

const _kEmptyCashCollectionFilters = (
  search: '',
  startDate: null,
  endDate: null,
);

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Manages the paginated cash collection list with search/date filters and running cash totals.
class CashCollectionCubit
    extends
        FilteredPaginationCubit<CashCollectionModel, CashCollectionFilters> {
  final CashCollectionRepository _repository;

  CashCollectionCubit({CashCollectionRepository? repository})
    : _repository = repository ?? CashCollectionRepository(),
      super(_kEmptyCashCollectionFilters);

  String get search => currentFilters.search;
  String? get startDate => currentFilters.startDate;
  String? get endDate => currentFilters.endDate;

  dynamic get cashInHand {
    final s = state;
    return s is PaginationLoaded<CashCollectionModel>
        ? (s.meta as CashCollectionMeta?)?.cashInHand
        : null;
  }

  dynamic get cashCollected {
    final s = state;
    return s is PaginationLoaded<CashCollectionModel>
        ? (s.meta as CashCollectionMeta?)?.cashCollected
        : null;
  }

  @override
  PaginationFetcher<CashCollectionModel> buildFetcher(
    CashCollectionFilters filters,
  ) => (offset) => _repository.getCashCollections(
    search: filters.search,
    startDate: filters.startDate,
    endDate: filters.endDate,
    offset: offset,
  );

  // Backward-compatible aliases for existing call sites.
  /// Load the first page of cash collections.
  Future<void> loadCollections() => fetchInitial();

  /// Load the next page of cash collections.
  Future<void> loadMore() => fetchMore();

  /// Apply filters and reload from the first page.
  Future<void> updateFilters({
    String? search,
    String? startDate,
    String? endDate,
  }) {
    return applyFilters((
      search: search ?? '',
      startDate: startDate,
      endDate: endDate,
    ));
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilters(_kEmptyCashCollectionFilters);

  bool get hasActiveFilters =>
      search.isNotEmpty || startDate != null || endDate != null;
}
