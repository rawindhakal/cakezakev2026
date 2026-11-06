import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';

/// Handles API calls for fetching and saving notification status settings.
class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches the current notification settings from the server.
  Future<AppNotificationSettings> getNotificationSettings() async {
    final response = await _apiClient.get(ApiEndpoints.notificationPreferences);
    return AppNotificationSettings.fromJson(response);
  }

  /// Saves the per-event notification channel selections to the server.
  Future<AppNotificationSettings> saveNotificationSettings({
    required List<Events> preferences,
  }) async {
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
  }
}
