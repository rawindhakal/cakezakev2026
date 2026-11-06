import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/products/models/product_rating_model.dart';
import 'package:customer/features/products/repositories/product_repository.dart';

class RatingsListCubit
    extends FilteredPaginationCubit<ProductRatingList, String> {
  final ProductRepository _repository;

  // Rating-summary fields come back on every page of the same response —
  // they aren't part of the paginated list itself, so they live outside
  // PaginationLoaded<T>.
  ProductRatingData _summary = ProductRatingData();
  ProductRatingData get summary => _summary;

  RatingsListCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super('');

  @override
  bool computeHasMore(
    PaginatedResponse<ProductRatingList> response,
    List<ProductRatingList> allData,
  ) => response.data.length >= AppConfig.pageLimit;

  @override
  PaginationFetcher<ProductRatingList> buildFetcher(String productId) =>
      (offset) async {
        final result = await _repository.getRatingsList(
          offset: offset,
          limit: AppConfig.pageLimit,
          productId: productId,
        );
        final data = result.data;
        if (data != null) {
          _summary = ProductRatingData(
            averageRating: data.averageRating,
            oneStarRating: data.oneStarRating,
            twoStarRating: data.twoStarRating,
            threeStarRating: data.threeStarRating,
            fourStarRating: data.fourStarRating,
            fiveStarRating: data.fiveStarRating,
          );
        }
        return PaginatedResponse(data: data?.ratingList ?? [], total: 0);
      };

  Future<void> loadRatings({required String productId}) =>
      applyFilters(productId);

  Future<void> loadMore() => fetchMore();
}
