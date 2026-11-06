import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/configs/app_config.dart';
import '../models/blog_model.dart';
import '../repositories/blog_repository.dart';

// ── Cubit ────────────────────────────────────────────────────────────────────
// Filter param is the optional category id. Access the active category via
// `currentFilters` (do not store it on the emitted state).
class BlogCubit extends FilteredPaginationCubit<Blog, String?> {
  final BlogRepository _repository;

  BlogCubit({BlogRepository? repository})
    : _repository = repository ?? BlogRepository(),
      super(null);

  @override
  PaginationFetcher<Blog> buildFetcher(String? categoryId) => (offset) async {
    final result = await _repository.getBlogs(
      offset: offset,
      categoryId: categoryId,
    );
    return PaginatedResponse(
      data: result.data ?? [],
      total: int.tryParse(result.total ?? '0') ?? 0,
    );
  };

  // API doesn't return a reliable total for this endpoint; fall back to
  // page-length based hasMore, matching the previous behaviour.
  @override
  bool computeHasMore(PaginatedResponse<Blog> response, List<Blog> allData) =>
      response.data.length >= AppConfig.pageLimit;

  void loadBlogs({String? categoryId}) => applyFilters(categoryId);

  Future<void> filterByCategory(String? categoryId) => applyFilters(categoryId);
}
