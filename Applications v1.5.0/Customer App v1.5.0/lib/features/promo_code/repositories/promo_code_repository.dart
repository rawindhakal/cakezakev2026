import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';

class PromoCodeRepository {
  final ApiClient _apiClient;

  PromoCodeRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PromoCode> getPromoCodes({
    required String amount,
    String? latitude,
    String? longitude,
    DeliveryType deliveryType = DeliveryType.delivery,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final response =
          await _apiClient.get(
                ApiEndpoints.promoCode,
                queryParameters: {
                  ApiParameters.amount: amount,
                  ApiParameters.latitude:
                      (latitude != null && latitude.isNotEmpty)
                      ? latitude
                      : hive.userLatitude,
                  ApiParameters.longitude:
                      (longitude != null && longitude.isNotEmpty)
                      ? longitude
                      : hive.userLongitude,
                  ApiParameters.platform: 'app',
                  ApiParameters.deliveryType: deliveryType.apiValue,
                },
              )
              as Map<String, dynamic>;
      return PromoCode.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<PromoCodeData> validatePromoCode({
    required String promoCode,
    required String total,
    String? latitude,
    String? longitude,
    DeliveryType deliveryType = DeliveryType.delivery,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final response =
          await _apiClient.post(
                ApiEndpoints.promoCodeValidate,
                queryParameters: {
                  ApiParameters.promoCode: promoCode,
                  ApiParameters.total: total,
                  ApiParameters.latitude:
                      (latitude != null && latitude.isNotEmpty)
                      ? latitude
                      : hive.userLatitude,
                  ApiParameters.longitude:
                      (longitude != null && longitude.isNotEmpty)
                      ? longitude
                      : hive.userLongitude,
                  ApiParameters.platform: 'app',
                  ApiParameters.deliveryType: deliveryType.apiValue,
                },
              )
              as Map<String, dynamic>;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return PromoCodeData.fromJson(data);
      }
      throw ApiException(
        message:
            response['message']?.toString() ??
            LocalizationService.instance.translate(
              LanguageLabelKeys.invalidPromoCode,
            ),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
