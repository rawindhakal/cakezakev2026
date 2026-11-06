import 'package:dio/dio.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/commons/models/country_settings_model.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';

class SettingsRepository {
  final ApiClient _apiClient;

  SettingsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();
  Future<AppSettings> getSettings() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.settings,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final settingsData = response['data'] as Map<String, dynamic>?;
      if (settingsData == null) {
        throw ApiException(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        );
      }

      return AppSettings(
        message: response['message']?.toString(),
        data: AppSettingsData.fromJson(settingsData),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// [latitude]/[longitude] override the session location. The server
  /// resolves the country from these coordinates, and `buyer_tax_field`
  /// follows the BUYER's country (a UAE buyer ordering from an Indian store is
  /// asked for a TRN) — so checkout passes the billed address's own
  /// coordinates to read the spec per address, not once per session.
  Future<CountrySettings> getCountrySettings({
    String? latitude,
    String? longitude,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final response = await _apiClient.get(
        ApiEndpoints.countrySettings,
        queryParameters: {
          ApiParameters.latitude: latitude ?? hive.userLatitude,
          ApiParameters.longitude: longitude ?? hive.userLongitude,
        },
      );
      return CountrySettings.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
