import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/notifications/notification/models/notification_model.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PaginatedResponse<NotificationModelData>> getNotifications({
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.notification,
        queryParameters: {
          ApiParameters.offset: offset,
          ApiParameters.limit: limit,
        },
      );
      return PaginatedResponse.fromJson(
        response as Map<String, dynamic>,
        NotificationModelData.fromJson,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
