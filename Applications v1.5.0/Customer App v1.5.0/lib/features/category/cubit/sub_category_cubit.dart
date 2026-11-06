import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/repositories/category_repository.dart';

class SubCategoryCubit extends BasePaginationCubit<Category> {
  final CategoryRepository _repo;
  String parentCategoryId;

  SubCategoryCubit({
    required this.parentCategoryId,
    CategoryRepository? repository,
  }) : _repo = repository ?? CategoryRepository();

  @override
  PaginationFetcher<Category> get fetcher =>
      (offset) => _repo.getCategories(
        offset: offset,
        limit: AppConfig.pageLimit,
        categoryId: parentCategoryId,
      );

  // Sub-category API may not return a reliable total — use page-count check.
  @override
  bool computeHasMore(
    PaginatedResponse<Category> response,
    List<Category> allData,
  ) => response.data.length >= AppConfig.pageLimit;

  void loadSubCategories() => fetchInitial();
  Future<void> loadMore() => fetchMore();

  // Drill into a deeper level — used when a sidebar item itself has children.
  Future<void> switchParent(String newParentId) {
    parentCategoryId = newParentId;
    return fetchInitial();
  }
}

// Distinct type from SubCategoryCubit so it resolves via its own BlocProvider —
// holds the right-side child list shown when the first auto-selected category has children.
class SubCategoryChildrenCubit extends SubCategoryCubit {
  SubCategoryChildrenCubit({super.parentCategoryId = '', super.repository});
}
