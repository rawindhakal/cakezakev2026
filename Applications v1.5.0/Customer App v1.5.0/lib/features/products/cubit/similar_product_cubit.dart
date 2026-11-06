import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/products/models/product_model.dart';
import '../repositories/product_repository.dart';

class SimilarProductCubit
    extends FilteredPaginationCubit<ProductDataModel, String> {
  final ProductRepository _repository;

  SimilarProductCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super('');

  @override
  PaginationFetcher<ProductDataModel> buildFetcher(String productId) {
    return (offset) async {
      final result = await _repository.getSimilarProducts(
        offset: offset,
        limit: AppConfig.pageLimit,
        isSimilarProductId: productId,
      );
      return PaginatedResponse(
        data: result.data ?? [],
        total: result.total ?? 0,
      );
    };
  }
}
