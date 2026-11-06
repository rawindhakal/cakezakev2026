import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/repositories/category_repository.dart';

class CategoryCubit extends BasePaginationCubit<Category> {
  final CategoryRepository _repo;

  CategoryCubit({CategoryRepository? repository})
    : _repo = repository ?? CategoryRepository();

  // Bumped by every loadCategories — older responses are discarded.
  int _generation = 0;
  // Generation of the list currently on screen; differs from _generation
  // while a refresh is in flight.
  int _loadedGeneration = -1;

  @override
  PaginationFetcher<Category> get fetcher =>
      (offset) =>
          _repo.getCategories(offset: offset, limit: AppConfig.pageLimit);

  @override
  Future<void> fetchInitial() => loadCategories();

  @override
  Future<void> fetchMore() => loadMore();

  /// Skeleton only when nothing is on screen yet (first load / after an
  /// error) or [emitLoadingState] is set. A refresh (pull, location /
  /// language change, reconnect) keeps the current grid until the new list
  /// lands, and only the latest call's response is applied.
  Future<void> loadCategories({bool emitLoadingState = false}) async {
    final generation = ++_generation;
    if (emitLoadingState || state is! PaginationLoaded<Category>) {
      emit(const PaginationLoading<Category>());
    }
    try {
      final response = await fetcher(0);
      if (generation != _generation) return;
      _loadedGeneration = generation;
      emit(
        PaginationLoaded<Category>(
          data: response.data,
          total: response.total,
          hasMore: computeHasMore(response, response.data),
        ),
      );
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(PaginationError<Category>(e.message));
    } catch (_) {
      if (generation != _generation) return;
      emit(
        PaginationError<Category>(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! PaginationLoaded<Category> ||
        current.isFetchingMore ||
        !current.hasMore ||
        // Refresh in flight — the list on screen is about to be replaced.
        _loadedGeneration != _generation) {
      return;
    }
    final generation = _generation;
    emit(current.copyWith(isFetchingMore: true));
    try {
      final response = await fetcher(current.data.length);
      if (generation != _generation) return;
      final all = [...current.data, ...response.data];
      emit(
        PaginationLoaded<Category>(
          data: all,
          total: response.total,
          hasMore: computeHasMore(response, all),
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      // Load-more failures stay silent — keep the loaded grid. An empty page
      // ends the list; other errors let the next scroll retry.
      emit(
        current.copyWith(
          isFetchingMore: false,
          hasMore: !BasePaginationCubit.isEndOfList(e),
        ),
      );
    }
  }
}
