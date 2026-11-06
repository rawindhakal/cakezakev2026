import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/products/models/product_model.dart';

class FavoriteRepository {
  final ApiClient _apiClient;

  FavoriteRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ProductModel> getFavorites({
    required int offset,
    required int limit,
  }) async {
    try {
      final lat = SettingsHiveBox.instance.userLatitude;
      final lng = SettingsHiveBox.instance.userLongitude;
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.latitude: lat,
        ApiParameters.longitude: lng,
      };
      final response = await _apiClient.get(
        ApiEndpoints.favorite,
        queryParameters: params,
      );
      return ProductModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductDataModel?> addToFavorite({required String productId}) async {
    try {
      final params = <String, dynamic>{ApiParameters.productId: productId};
      final response = await _apiClient.post(
        ApiEndpoints.addProductToFavorite,
        queryParameters: params,
      );
      final map = response as Map<String, dynamic>;
      final rawData = map['data'];
      if (rawData is List && rawData.isNotEmpty) {
        return ProductDataModel.fromJson(rawData.first as Map<String, dynamic>);
      }
      if (rawData is Map<String, dynamic>) {
        return ProductDataModel.fromJson(rawData);
      }
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> removeFromFavorite({required String productId}) async {
    try {
      final params = <String, dynamic>{ApiParameters.productId: productId};
      await _apiClient.post(
        ApiEndpoints.removeProductFromFavorite,
        queryParameters: params,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
