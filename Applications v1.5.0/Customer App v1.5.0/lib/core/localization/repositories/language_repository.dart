import 'package:customer/core/localization/models/language_model.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';

class LanguageRepository {
  final ApiClient _apiClient;

  LanguageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<LanguageJsonData>> fetchLanguages() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.systemLanguages,
        queryParameters: {ApiParameters.systemType: '1'},
      );
      final json = response as Map<String, dynamic>;
      final list = json['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => LanguageJsonData.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<LanguageJsonData> fetchLanguageById(String id) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.systemLanguages,
        queryParameters: {ApiParameters.systemType: '1', ApiParameters.id: id},
      );
      final json = response as Map<String, dynamic>;

      final data = json['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ApiException(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        );
      }

      return LanguageJsonData.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
