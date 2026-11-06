import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef PaginationFetcher<T> =
    Future<PaginatedResponse<T>> Function(int offset);

// ── States ────────────────────────────────────────────────────────────────────
/// Base state for [BasePaginationCubit].
sealed class PaginationState<T> {
  const PaginationState();
}

/// Initial state before the first page is fetched.
final class PaginationInitial<T> extends PaginationState<T> {
  const PaginationInitial();
}

/// Emitted while the first page is loading.
final class PaginationLoading<T> extends PaginationState<T> {
  const PaginationLoading();
}

/// Emitted once at least one page of data has loaded successfully.
final class PaginationLoaded<T> extends PaginationState<T> {
  final List<T> data;
  final int total;
  final bool isFetchingMore;
  final bool hasMore;

  /// Optional extra payload alongside the list (e.g. cash-in-hand/collected
  /// or wallet balance) for cubits whose Loaded state needs more than
  /// list/total. Null for cubits that don't use it.
  final Object? meta;

  const PaginationLoaded({
    required this.data,
    required this.total,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.meta,
  });

  PaginationLoaded<T> copyWith({
    List<T>? data,
    int? total,
    bool? isFetchingMore,
    bool? hasMore,
    Object? meta,
  }) {
    return PaginationLoaded<T>(
      data: data ?? this.data,
      total: total ?? this.total,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      meta: meta ?? this.meta,
    );
  }
}

/// Emitted when fetching a page fails.
final class PaginationError<T> extends PaginationState<T> {
  final String message;
  const PaginationError(this.message) : super();
}

// ── Base Cubit ────────────────────────────────────────────────────────────────
/// Generic offset-based pagination cubit: fetches, appends, and tracks "has more" pages.
abstract class BasePaginationCubit<T> extends Cubit<PaginationState<T>> {
  BasePaginationCubit() : super(PaginationInitial<T>());

  PaginationFetcher<T> get fetcher;

  // Bumped on every fetchInitial call so a slow, superseded response (e.g. the
  // unfiltered load still in flight when a filter is applied) can be detected
  // and dropped instead of overwriting newer state.
  int _requestId = 0;

  // Override to customise when hasMore is true.
  // Default: exact total-based check. Use page-count override for APIs that
  // don't return reliable totals: `response.data.length >= AppConfig.pageLimit`
  /// Determines whether more pages remain after [allData] loaded from [response].
  bool computeHasMore(PaginatedResponse<T> response, List<T> allData) =>
      allData.length < response.total;

  /// Fetches and emits the first page, replacing any existing data.
  Future<void> fetchInitial() async {
    final requestId = ++_requestId;
    emit(PaginationLoading<T>());
    try {
      final response = await fetcher(0);
      if (requestId != _requestId) return;
      emit(
        PaginationLoaded<T>(
          data: response.data,
          total: response.total,
          hasMore: computeHasMore(response, response.data),
          meta: response.meta,
        ),
      );
    } on ApiException catch (e) {
      if (requestId != _requestId) return;
      emit(PaginationError<T>(e.message));
    } catch (_) {
      if (requestId != _requestId) return;
      emit(
        PaginationError<T>(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Fetches and appends the next page, no-op if already fetching or no more pages remain.
  Future<void> fetchMore() async {
    final current = state;
    if (current is! PaginationLoaded<T> ||
        current.isFetchingMore ||
        !current.hasMore) {
      return;
    }

    emit(current.copyWith(isFetchingMore: true));
    try {
      final response = await fetcher(current.data.length);
      final all = [...current.data, ...response.data];
      emit(
        PaginationLoaded<T>(
          data: all,
          total: response.total,
          hasMore: computeHasMore(response, all),
          meta: response.meta,
        ),
      );
    } on ApiException catch (e) {
      emit(current.copyWith(isFetchingMore: false));
      emit(PaginationError<T>(e.message));
    } catch (_) {
      emit(current.copyWith(isFetchingMore: false));
      emit(
        PaginationError<T>(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> refresh() => fetchInitial();
}

// ── Filtered Cubit ────────────────────────────────────────────────────────────
// Extend this when pagination needs dynamic filter params (category, date range,
// search query, etc.). Implement [buildFetcher] and call [applyFilters] to reset
// the list and re-fetch with new params. Access current params via [currentFilters].
/// Base pagination cubit for lists driven by dynamic filter params (category, date range, search).
abstract class FilteredPaginationCubit<T, F> extends BasePaginationCubit<T> {
  F _filters;

  FilteredPaginationCubit(F initialFilters) : _filters = initialFilters;

  PaginationFetcher<T> buildFetcher(F filters);

  @override
  PaginationFetcher<T> get fetcher => buildFetcher(_filters);

  F get currentFilters => _filters;

  /// Replaces the current filters and re-fetches the first page with them.
  Future<void> applyFilters(F filters) {
    _filters = filters;
    return fetchInitial();
  }
}
