import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/products/repositories/product_repository.dart';

class RatingImagesCubit extends FilteredPaginationCubit<String, String> {
  final ProductRepository _repository;

  RatingImagesCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super('');

  @override
  PaginationFetcher<String> buildFetcher(String productId) {
    return (offset) async {
      final result = await _repository.getRatingImages(
        offset: offset,
        limit: AppConfig.pageLimit,
        productId: productId,
      );
      return PaginatedResponse(
        data: result.data ?? [],
        total: int.tryParse(result.total ?? '0') ?? 0,
      );
    };
  }
}
