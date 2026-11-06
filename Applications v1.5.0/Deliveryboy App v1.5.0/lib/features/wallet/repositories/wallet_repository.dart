import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';

/// Handles wallet balance and withdrawal-request API calls.
class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// POST /withdrawal-requests/add
  Future<void> addWithdrawalRequest({
    required String amount,
    String? message,
  }) async {
    final data = <String, dynamic>{
      ApiParameters.amount: amount,
      if (message != null && message.isNotEmpty) ApiParameters.message: message,
    };
    await _apiClient.post(ApiEndpoints.addWithdrawalRequest, data: data);
  }

  /// GET /withdrawal-request — paginated list with optional filters.
  Future<PaginatedResponse<WithdrawRequests>> getWithdrawalRequests({
    String? search,
    String? status, // -1 = all, 0 = pending, 1 = approved, 2 = rejected
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    final params = <String, dynamic>{
      ApiParameters.offset: offset,
      ApiParameters.limit: limit,
      if (search != null && search.isNotEmpty) ApiParameters.search: search,
      if (status != null && status != "")
        ApiParameters.status: status.toString(),
    };

    final response =
        await _apiClient.get(
              ApiEndpoints.getWithdrawalRequests,
              queryParameters: params,
            )
            as Map<String, dynamic>;
    final walletData = response['data'] != null
        ? Data.fromJson(response['data'])
        : null;
    return PaginatedResponse<WithdrawRequests>(
      data: walletData?.withdrawRequests ?? [],
      total: int.tryParse(response['total']?.toString() ?? '0') ?? 0,
      meta: double.tryParse(walletData?.balance ?? '0') ?? 0.0,
    );
  }
}
