import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import '../models/settlement_history_model.dart';

/// Handles fund transfer / settlement history API calls.
class SettlementHistoryRepository {
  final ApiClient _apiClient;

  SettlementHistoryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch a paginated, filterable page of fund transfer/settlement entries.
  Future<SettlementHistoryResponse> getSettlementHistorys({
    String? search,
    String? entryType,
    String? startDate,
    String? endDate,
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    final params = <String, dynamic>{
      ApiParameters.offset: offset,
      ApiParameters.limit: limit,
      if (search != null && search.isNotEmpty) ApiParameters.search: search,
      if (entryType != null && entryType.isNotEmpty)
        ApiParameters.entryType: entryType,
      if (startDate != null && startDate.isNotEmpty)
        ApiParameters.startDate: startDate,
      if (endDate != null && endDate.isNotEmpty) ApiParameters.endDate: endDate,
    };

    final response = await _apiClient.get(
      ApiEndpoints.settlementHistory,
      queryParameters: params,
    );
    return SettlementHistoryResponse.fromJson(response as Map<String, dynamic>);
  }
}
