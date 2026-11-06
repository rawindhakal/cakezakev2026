import 'package:deliveryboy/core/localization/models/language_model.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';

/// Fetches system language list/detail data from the backend.
class LanguageRepository {
  final ApiClient _apiClient;

  LanguageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches the full list of available system languages.
  Future<List<LanguageJsonData>> fetchLanguages() async {
    final response = await _apiClient.get(
      ApiEndpoints.systemLanguages,
      queryParameters: {ApiParameters.systemType: '2'},
    );
    final json = response as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => LanguageJsonData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single language's full data, including its translation JSON, by [id].
  Future<LanguageJsonData> fetchLanguageById(String id) async {
    final response = await _apiClient.get(
      ApiEndpoints.systemLanguages,
      queryParameters: {ApiParameters.systemType: '2', ApiParameters.id: id},
    );
    /* final json = response as Map<String, dynamic>;
      final list = json['data'] as List<dynamic>? ?? [];
      if (list.isEmpty) throw ApiException(message: 'Language not found');
      return Data.fromJson(list.first as Map<String, dynamic>); */
    final json = response as Map<String, dynamic>;

    final data = json['data'];
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.invalidLanguageData,
        ),
      );
    }

    return LanguageJsonData.fromJson(data);
  }
}
