import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/commons/models/country_settings_model.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';

/// Fetches app-wide and per-country settings from the backend.
class SettingsRepository {
  final ApiClient _apiClient;

  SettingsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches the app-wide settings (branding, versioning, feature flags).
  Future<AppSettings> getSettings() async {
    final response =
        await _apiClient.get(ApiEndpoints.settings) as Map<String, dynamic>;
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.noDataInResponse,
        ),
      );
    }
    return AppSettings(
      status: response['status']?.toString(),
      message: response['message']?.toString(),
      data: AppSettingsData.fromJson(data),
    );
  }

  /// Fetches per-country settings (date/time format, currency, legal docs) for the user's location.
  Future<CountrySettings> getCountrySettings() async {
    final response = await _apiClient.get(ApiEndpoints.countrySettings);
    return CountrySettings.fromJson(response as Map<String, dynamic>);
  }
}
