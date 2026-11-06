import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/category/models/category_model.dart';

class CategoryRepository {
  final ApiClient _apiClient;

  CategoryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PaginatedResponse<Category>> getCategories({
    required int offset,
    required int limit,
    String? categoryId,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.categoryId: ?categoryId,
        ApiParameters.latitude: SettingsHiveBox.instance.userLatitude,
        ApiParameters.longitude: SettingsHiveBox.instance.userLongitude,
      };
      final response = await _apiClient.get(
        ApiEndpoints.categories,
        queryParameters: params,
      );
      return PaginatedResponse.fromJson(
        response as Map<String, dynamic>,
        Category.fromJson,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
