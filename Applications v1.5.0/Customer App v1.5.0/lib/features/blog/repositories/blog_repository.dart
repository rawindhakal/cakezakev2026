import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import '../models/blog_category_model.dart';
import '../models/blog_model.dart';

class BlogRepository {
  final ApiClient _apiClient;

  BlogRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<BlogCategoryResponse> getBlogCategories() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.blogCategories);
      return BlogCategoryResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<BlogResponse> getBlogs({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? categoryId,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.categoryId: categoryId,
      }..removeWhere((_, v) => v == null);

      final response = await _apiClient.get(
        ApiEndpoints.blogs,
        queryParameters: params,
      );
      return BlogResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
