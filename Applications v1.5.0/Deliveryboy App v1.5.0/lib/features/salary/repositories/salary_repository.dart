import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import '../models/salary_model.dart';

/// Handles salary payment history API calls.
class SalaryRepository {
  final ApiClient _apiClient;

  SalaryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch a paginated page of salary payment entries.
  Future<PaginatedResponse<SalaryModel>> getSalaries({
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    final params = <String, dynamic>{
      ApiParameters.offset: offset,
      ApiParameters.limit: limit,
    };

    final response = await _apiClient.get(
      ApiEndpoints.salary,
      queryParameters: params,
    );
    return PaginatedResponse.fromJson(
      response as Map<String, dynamic>,
      SalaryModel.fromJson,
    );
  }
}
