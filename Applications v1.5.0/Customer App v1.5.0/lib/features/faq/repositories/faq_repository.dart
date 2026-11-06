import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import '../models/faq_model.dart';

class FaqRepository {
  final ApiClient _apiClient;

  FaqRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<FaqResponse> getFaqs({
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
      };

      final response = await _apiClient.get(
        ApiEndpoints.faq,
        queryParameters: params,
      );
      return FaqResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
