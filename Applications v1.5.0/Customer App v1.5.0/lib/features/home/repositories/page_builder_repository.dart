import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/home/models/page_builder_model.dart';

class PageBuilderRepository {
  final ApiClient _apiClient;

  PageBuilderRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PageBuilderModel> getPageBuilder({
    required String id,
    int offset = 0,
    int limit = AppConstants.homeSectionsPageLimit,
  }) async {
    try {
      final lat = SettingsHiveBox.instance.userLatitude;
      final lng = SettingsHiveBox.instance.userLongitude;
      final params = <String, dynamic>{
        ApiParameters.latitude: lat,
        ApiParameters.longitude: lng,
        ApiParameters.id: id,
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
      };
      final response = await _apiClient.get(
        ApiEndpoints.pageBuilder,
        queryParameters: params,
      );
      return PageBuilderModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
