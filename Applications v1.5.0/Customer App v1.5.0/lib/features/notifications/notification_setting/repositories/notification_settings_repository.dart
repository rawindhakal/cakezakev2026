import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/features/notifications/notification_setting/models/notification_setting_model.dart';

class NotificationSettingsRepository {
  final ApiClient _apiClient;

  NotificationSettingsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<AppNotificationSettings> getNotificationSettings() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.notificationPreferences,
      );
      return AppNotificationSettings.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<AppNotificationSettings> saveNotificationSettings({
    required List<Events> preferences,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.notificationPreferences,
        data: {
          ApiParameters.preferences: preferences
              .map(
                (e) => {
                  ApiParameters.key: e.key,
                  ApiParameters.channels: e.channels?.toJson(),
                },
              )
              .toList(),
        },
      );
      return AppNotificationSettings.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
