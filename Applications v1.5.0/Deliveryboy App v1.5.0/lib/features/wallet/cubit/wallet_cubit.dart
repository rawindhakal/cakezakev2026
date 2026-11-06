import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import '../models/withdrawal_request_model.dart';
import '../repositories/wallet_repository.dart';

/// Re-exported so screens can keep using the previous state-type aliases.
typedef WalletState = PaginationState<WithdrawRequests>;
typedef WalletInitial = PaginationInitial<WithdrawRequests>;
typedef WalletLoading = PaginationLoading<WithdrawRequests>;
typedef WalletLoaded = PaginationLoaded<WithdrawRequests>;
typedef WalletError = PaginationError<WithdrawRequests>;

/// Active filter params for the wallet/withdrawal-requests list.
typedef WalletFilters = ({String search, String status});

const _kEmptyWalletFilters = (search: '', status: '');

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Manages the paginated wallet balance and withdrawal-request list with search/status filters.
class WalletCubit
    extends FilteredPaginationCubit<WithdrawRequests, WalletFilters> {
  final WalletRepository _repository;

  WalletCubit({WalletRepository? repository})
    : _repository = repository ?? WalletRepository(),
      super(_kEmptyWalletFilters);

  String get searchQuery => currentFilters.search;
  String get selectedStatus => currentFilters.status;

  double get balance {
    final s = state;
    return s is PaginationLoaded<WithdrawRequests>
        ? (s.meta as double?) ?? 0.0
        : 0.0;
  }

  @override
  PaginationFetcher<WithdrawRequests> buildFetcher(WalletFilters filters) =>
      (offset) => _repository.getWithdrawalRequests(
        search: filters.search,
        status: filters.status,
        offset: offset,
      );

  // Original behaviour paginates by page-count (limit) rather than total.
  @override
  bool computeHasMore(
    PaginatedResponse<WithdrawRequests> response,
    List<WithdrawRequests> allData,
  ) => response.data.length >= AppConfig.pageLimit;

  // Backward-compatible aliases for existing call sites.

  /// Fetch wallet data with pagination, search, and status filter.
  Future<void> fetchWalletData({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? search,
    String? status,
    bool isLoadMore = false,
  }) {
    if (isLoadMore) return fetchMore();
    return applyFilters((
      search: search ?? currentFilters.search,
      status: status ?? currentFilters.status,
    ));
  }

  /// Load the next page of transactions.
  Future<void> loadMore() => fetchMore();

  /// Search with filter.
  Future<void> search(String query) =>
      applyFilters((search: query, status: currentFilters.status));

  /// Filter by status.
  Future<void> filterByStatus(String status) =>
      applyFilters((search: currentFilters.search, status: status));

  /// Initial load.
  void loadWallet() => fetchInitial();
}
