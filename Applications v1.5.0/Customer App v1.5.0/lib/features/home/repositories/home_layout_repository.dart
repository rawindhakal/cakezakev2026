import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:dio/dio.dart';

class HomeLayoutRepository {
  final ApiClient _apiClient;

  HomeLayoutRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<HomeBuilderModel> getHomeLayout({
    String? channel,
    String? categoryId,
    int offset = 0,
    int limit = AppConstants.homeSectionsPageLimit,
  }) async {
    try {
      final lat = SettingsHiveBox.instance.userLatitude;
      final lng = SettingsHiveBox.instance.userLongitude;
      final params = <String, dynamic>{
        ApiParameters.latitude: lat,
        ApiParameters.longitude: lng,
        ApiParameters.device: AppSizes.isTabletDevice
            ? ApiParameters.tablet
            : ApiParameters.app,
        ApiParameters.categoryId: ?categoryId,
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
      };
      final response = await _apiClient.get(
        ApiEndpoints.homeLayout,
        queryParameters: params,
        // Pinned per request so a quick/ecommerce layout always loads its
        // own catalog, even if the session channel flips mid-flight.
        options: channel == null
            ? null
            : Options(headers: {ApiParameters.channel: channel}),
      );
      return HomeBuilderModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
