import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import '../models/cash_collection_model.dart';

/// Handles cash collection history API calls.
class CashCollectionRepository {
  final ApiClient _apiClient;

  CashCollectionRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch a paginated, filterable page of cash collection entries.
  Future<PaginatedResponse<CashCollectionModel>> getCashCollections({
    String? search,
    String? startDate,
    String? endDate,
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    final params = <String, dynamic>{
      ApiParameters.offset: offset,
      ApiParameters.limit: limit,
      if (search != null && search.isNotEmpty) ApiParameters.search: search,
      if (startDate != null && startDate.isNotEmpty)
        ApiParameters.startDate: startDate,
      if (endDate != null && endDate.isNotEmpty) ApiParameters.endDate: endDate,
    };

    final response =
        await _apiClient.get(ApiEndpoints.cashCollection, queryParameters: params)
            as Map<String, dynamic>;
    final cashData = response['data'] != null
        ? CashCollectionData.fromJson(response['data'])
        : null;
    return PaginatedResponse<CashCollectionModel>(
      data: cashData?.cashCollections ?? [],
      total: int.tryParse(response['total']?.toString() ?? '0') ?? 0,
      meta: CashCollectionMeta(
        cashInHand: cashData?.cashInHand,
        cashCollected: cashData?.cashCollected,
      ),
    );
  }
}
