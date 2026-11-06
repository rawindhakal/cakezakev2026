import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef PaginationFetcher<T> =
    Future<PaginatedResponse<T>> Function(int offset);

// ── States ────────────────────────────────────────────────────────────────────
sealed class PaginationState<T> {
  const PaginationState();
}

final class PaginationInitial<T> extends PaginationState<T> {
  const PaginationInitial();
}

final class PaginationLoading<T> extends PaginationState<T> {
  const PaginationLoading();
}

final class PaginationLoaded<T> extends PaginationState<T> {
  final List<T> data;
  final int total;
  final bool isFetchingMore;
  final bool hasMore;

  const PaginationLoaded({
    required this.data,
    required this.total,
    this.isFetchingMore = false,
    this.hasMore = true,
  });

  PaginationLoaded<T> copyWith({
    List<T>? data,
    int? total,
    bool? isFetchingMore,
    bool? hasMore,
  }) {
    return PaginationLoaded<T>(
      data: data ?? this.data,
      total: total ?? this.total,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final class PaginationError<T> extends PaginationState<T> {
  final String message;
  const PaginationError(this.message) : super();
}

// ── Base Cubit ────────────────────────────────────────────────────────────────
abstract class BasePaginationCubit<T> extends Cubit<PaginationState<T>> {
  BasePaginationCubit() : super(PaginationInitial<T>());

  PaginationFetcher<T> get fetcher;

  // Override to customise when hasMore is true.
  // Default: exact total-based check. Use page-count override for APIs that
  // don't return reliable totals: `response.data.length >= AppConfig.pageLimit`
  bool computeHasMore(PaginatedResponse<T> response, List<T> allData) =>
      allData.length < response.total;

  Future<void> fetchInitial() async {
    emit(PaginationLoading<T>());
    try {
      final response = await fetcher(0);
      emit(
        PaginationLoaded<T>(
          data: response.data,
          total: response.total,
          hasMore: computeHasMore(response, response.data),
        ),
      );
    } on ApiException catch (e) {
      emit(PaginationError<T>(e.message));
    } catch (_) {
      emit(
        PaginationError<T>(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

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
        ),
      );
    } catch (e) {
      // Never wipe already-loaded items on a failed next page. List APIs
      // answer an empty page with HTTP 200 + `status: 0` ("No ... Found!"):
      // that is the end of the list. Anything else (network / server error)
      // keeps hasMore so the next scroll retries.
      emit(
        current.copyWith(
          isFetchingMore: false,
          hasMore: !isEndOfList(e),
        ),
      );
    }
  }

  static bool isEndOfList(Object error) =>
      error is ApiException && error.statusCode == 200;

  Future<void> refresh() => fetchInitial();

  // Inserts a freshly-created item at the top of the list (e.g. a reward
  // just won) without a refetch — bumps total to match.
  void prependItem(T item) {
    final current = state;
    if (current is! PaginationLoaded<T>) return;
    emit(
      current.copyWith(data: [item, ...current.data], total: current.total + 1),
    );
  }

  void updateItem(bool Function(T) predicate, T updated) {
    final current = state;
    if (current is! PaginationLoaded<T>) return;
    final idx = current.data.indexWhere(predicate);
    if (idx == -1) return;
    final updated_ = List<T>.of(current.data)..[idx] = updated;
    emit(current.copyWith(data: updated_));
  }

  void removeItem(bool Function(T) predicate) {
    final current = state;
    if (current is! PaginationLoaded<T>) return;
    final updated = current.data.where((item) => !predicate(item)).toList();
    if (updated.length == current.data.length) return;
    emit(current.copyWith(data: updated, total: current.total - 1));
  }
}

// ── Filtered Cubit ────────────────────────────────────────────────────────────
// Extend this when pagination needs dynamic filter params (category, date range,
// search query, etc.). Implement [buildFetcher] and call [applyFilters] to reset
// the list and re-fetch with new params. Access current params via [currentFilters].
abstract class FilteredPaginationCubit<T, F> extends BasePaginationCubit<T> {
  F _filters;

  FilteredPaginationCubit(F initialFilters) : _filters = initialFilters;

  PaginationFetcher<T> buildFetcher(F filters);

  @override
  PaginationFetcher<T> get fetcher => buildFetcher(_filters);

  F get currentFilters => _filters;

  Future<void> applyFilters(F filters) {
    _filters = filters;
    return fetchInitial();
  }
}
