import 'dart:convert';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/payment_method/models/initiate_transaction_model.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';

class PaymentRepository {
  PaymentRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PaymentMethods> getPaymentMethods() async {
    try {
      final hive = SettingsHiveBox.instance;
      final response = await _apiClient.get(
        ApiEndpoints.paymentMethodsSettings,
        queryParameters: {
          ApiParameters.latitude: hive.userLatitude,
          ApiParameters.longitude: hive.userLongitude,
        },
      );
      final responseMap = response as Map<String, dynamic>;

      // data field is Base64-encoded JSON — decode before parsing
      final rawData = responseMap['data'];
      if (rawData is String && rawData.isNotEmpty) {
        final decodedBytes = base64.decode(rawData);
        final decodedString = utf8.decode(decodedBytes);
        responseMap['data'] =
            json.decode(decodedString) as Map<String, dynamic>;
      }

      return PaymentMethods.fromJson(responseMap);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<InitiateTransactionResponse> initiateTransaction({
    required Map<String, dynamic> params,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final response = await _apiClient.post(
        ApiEndpoints.initiateTransaction,
        data: {
          ...params,
          ApiParameters.latitude: hive.userLatitude,
          ApiParameters.longitude: hive.userLongitude,
        },
      );
      return InitiateTransactionResponse.fromJson(
        response as Map<String, dynamic>,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> addTransaction({required Map<String, dynamic> params}) async {
    try {
      final hive = SettingsHiveBox.instance;
      await _apiClient.post(
        ApiEndpoints.addTransaction,
        data: {
          ...params,
          ApiParameters.latitude: hive.userLatitude,
          ApiParameters.longitude: hive.userLongitude,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> orderStatusPhonePe({
    required String merchantOrderId,
    required String token,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.orderStatusPhonepe,
        queryParameters: {
          ApiParameters.transactionId: merchantOrderId,
          ApiParameters.token: token,
        },
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
