import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:dio/dio.dart';
import '../models/spin_wheel_model.dart';

class SpinWheelRepository {
  final ApiClient _apiClient;

  SpinWheelRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<SpinWheelResponse> getSpinWheel() async {
    try {
      final params = <String, dynamic>{
        ApiParameters.latitude: SettingsHiveBox.instance.userLatitude,
        ApiParameters.longitude: SettingsHiveBox.instance.userLongitude,
      };
      final response = await _apiClient.get(
        ApiEndpoints.spinWheel,
        queryParameters: params,
      );
      return SpinWheelResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SpinResultResponse> spin({required String requestToken}) async {
    try {
      final formData = FormData.fromMap({
        ApiParameters.latitude: SettingsHiveBox.instance.userLatitude,
        ApiParameters.longitude: SettingsHiveBox.instance.userLongitude,
        ApiParameters.requestToken: requestToken,
      });
      final response = await _apiClient.upload(
        ApiEndpoints.spinWheelSpin,
        formData: formData,
      );
      return SpinResultResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SpinRewardsResponse> getRewards({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    // '' (SpinRewardFilterType.all) means "no filter" — sent as-is, not
    // omitted, per the API contract.
    String rewardType = '',
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.latitude: SettingsHiveBox.instance.userLatitude,
        ApiParameters.longitude: SettingsHiveBox.instance.userLongitude,
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.rewardType: rewardType,
      };
      final response = await _apiClient.get(
        ApiEndpoints.spinWheelRewards,
        queryParameters: params,
      );
      return SpinRewardsResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
