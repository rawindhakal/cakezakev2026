import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/features/wallet/models/transaction_model.dart';
import 'package:customer/features/wallet/models/wallet_history_model.dart';

class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// GET /get_user_transactions — paginated user transaction history.
  Future<PaginatedResponse<TransactionData>> getUserTransactions({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String type = 'transactions',
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.type: type,
      };
      final response = await _apiClient.get(
        ApiEndpoints.transaction,
        queryParameters: params,
      );
      return PaginatedResponse.fromJson(
        response as Map<String, dynamic>,
        TransactionData.fromJson,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /get_user_transactions — paginated wallet history.
  Future<PaginatedResponse<WalletHistoryData>> getWalletHistory({
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.type: AppConstants.wallet,
      };
      final response = await _apiClient.get(
        ApiEndpoints.transaction,
        queryParameters: params,
      );
      return PaginatedResponse.fromJson(
        response as Map<String, dynamic>,
        WalletHistoryData.fromJson,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
