import 'dart:io';

import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class OrderRepository {
  final ApiClient _apiClient;

  OrderRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// GET /orders?order_id — fetch full order detail by order id.
  Future<OrderData> getOrderDetail(String orderId) async {
    try {
      final response =
          await _apiClient.get(
                ApiEndpoints.orders,
                queryParameters: {ApiParameters.orderId: orderId},
              )
              as Map<String, dynamic>;
      final data = response['data'];
      final Map<String, dynamic> orderJson;
      if (data is List && data.isNotEmpty) {
        orderJson = Map<String, dynamic>.from(data.first);
      } else if (data is Map<String, dynamic>) {
        orderJson = data;
      } else {
        throw ApiException(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.orderNotFound,
          ),
        );
      }
      return OrderData.fromJson(orderJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /update_status — update order status.
  ///
  /// [orderItemId] is only sent for ecommerce (item-wise) cancel/return —
  /// quick-commerce orders are cancelled as a whole, so leave it null there.
  /// [from] is `'cancel'` or `'return'`; [reason] becomes `cancellation_reason`
  /// for cancel or `reason` for return.
  /// Returns the `data` object from the response — the updated order item —
  /// so callers can patch local state instead of refetching.
  Future<Map<String, dynamic>?> updateOrderStatus({
    required String orderId,
    required String status,
    String? orderItemId,
    String? from,
    String? reason,
    String? addressId,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await _apiClient.post(
        ApiEndpoints.updateOrderStatus,
        data: {
          ApiParameters.orderId: orderId,
          ApiParameters.orderItemId: orderItemId ?? '',
          ApiParameters.status: status,
          ApiParameters.deviceType: AppConstants.platformType,
          ApiParameters.appVersion: packageInfo.version,
          if (from == 'cancel' && reason != null)
            ApiParameters.cancellationReason: reason,
          if (from == 'return' && reason != null)
            ApiParameters.returnReason: reason,
          if (from == 'return' && addressId != null)
            ApiParameters.addressId: addressId,
        },
      );
      final map = response as Map<String, dynamic>;

      final data = map['data'];

      if (data is List && data.isNotEmpty) {
        return data.first as Map<String, dynamic>;
      }

      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /delete_order — delete an order left in "awaiting payment" state
  /// when a payment gateway attempt fails or is cancelled by the user.
  Future<void> deleteOrder({required String orderId}) async {
    try {
      await _apiClient.post(
        ApiEndpoints.deleteOrder,
        data: {ApiParameters.orderId: orderId},
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /orders — ongoing orders (active = "1") with offset/limit pagination.
  Future<OrderModel> getOngoingOrders({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? channel,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.orders,
        queryParameters: {
          ApiParameters.offset: offset,
          ApiParameters.limit: limit,
          ApiParameters.type: ApiParameters.active,
          if (channel != null && channel.isNotEmpty)
            ApiParameters.channel: channel,
          if (startDate != null && startDate.isNotEmpty)
            ApiParameters.startDate: startDate,
          if (endDate != null && endDate.isNotEmpty)
            ApiParameters.endDate: endDate,
        },
      );
      return OrderModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /orders — completed orders (previous = "0") with offset/limit pagination.
  Future<OrderModel> getCompletedOrders({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? channel,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.orders,
        queryParameters: {
          ApiParameters.offset: offset,
          ApiParameters.limit: limit,
          ApiParameters.type: ApiParameters.previous,
          if (channel != null && channel.isNotEmpty)
            ApiParameters.channel: channel,
          if (startDate != null && startDate.isNotEmpty)
            ApiParameters.startDate: startDate,
          if (endDate != null && endDate.isNotEmpty)
            ApiParameters.endDate: endDate,
        },
      );
      return OrderModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /live_tracking?order_id — polls the delivery boy's current lat/lng for an order.
  Future<LiveLocation> getLiveLocation(String orderId) async {
    try {
      final response =
          await _apiClient.get(
                ApiEndpoints.liveTracking,
                queryParameters: {ApiParameters.orderId: orderId},
              )
              as Map<String, dynamic>;
      return LiveLocation.fromJson(
        response['data'] as Map<String, dynamic>? ?? {},
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Calls OSRM's free public routing API (no API key needed, third-party —
  /// goes through [ApiClient.external] rather than the app's own envelope-
  /// checked client) and decodes the road-following geometry. Returns null
  /// on any failure so callers can fall back to a direct line.
  Future<List<LatLng>?> getRoadRoute(LatLng from, LatLng to) async {
    try {
      final response = await ApiClient.external.get(
        '${ApiEndpoints.osrmRouteBaseUrl}'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}',
        queryParameters: const {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = response.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final coordinates = routes.first['geometry']['coordinates'] as List;
      return coordinates
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('OSRM route fetch failed: $e');
      return null;
    }
  }

  /// GET /ecom_orders — ongoing ecommerce order items (active = "1") with offset/limit pagination.
  Future<EcommerceOrderModel> getEcommerceOngoingOrders({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.ecomOrders,
        queryParameters: {
          ApiParameters.offset: offset,
          ApiParameters.limit: limit,
          ApiParameters.type: ApiParameters.active,
          if (startDate != null && startDate.isNotEmpty)
            ApiParameters.startDate: startDate,
          if (endDate != null && endDate.isNotEmpty)
            ApiParameters.endDate: endDate,
        },
      );
      return EcommerceOrderModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /ecom_orders — completed ecommerce order items (previous = "0") with offset/limit pagination.
  Future<EcommerceOrderModel> getEcommerceCompletedOrders({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.ecomOrders,
        queryParameters: {
          ApiParameters.offset: offset,
          ApiParameters.limit: limit,
          ApiParameters.type: ApiParameters.previous,
          if (startDate != null && startDate.isNotEmpty)
            ApiParameters.startDate: startDate,
          if (endDate != null && endDate.isNotEmpty)
            ApiParameters.endDate: endDate,
        },
      );
      return EcommerceOrderModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /invoice_download?order_id — fetch the invoice PDF bytes for a quick order
  /// and save them to a local file. API returns the raw PDF body, not JSON.
  Future<File> downloadQuickInvoice(String orderId) async {
    final bytes = await _apiClient.postBytes(
      ApiEndpoints.downloadOrderInvoice,
      data: {ApiParameters.orderId: orderId},
    );
    return _saveInvoiceFile(bytes, orderId);
  }

  /// POST /item_invoice_download?order_item_id — fetch the invoice PDF bytes
  /// for an ecommerce order item and save them to a local file.
  Future<File> downloadEcommerceInvoice(String orderItemId) async {
    final bytes = await _apiClient.postBytes(
      ApiEndpoints.downloadItemInvoice,
      data: {ApiParameters.orderItemId: orderItemId},
    );
    return _saveInvoiceFile(bytes, orderItemId);
  }

  Future<File> _saveInvoiceFile(List<int> bytes, String idSuffix) async {
    if (bytes.isEmpty) {
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.invoiceNotFound,
        ),
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/invoice_$idSuffix.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// GET /ecom_orders?order_item_id — fetch ecommerce order item detail.
  Future<EcommerceOrderDataModel> getEcommerceOrderDetail(
    String orderItemId,
  ) async {
    try {
      final response =
          await _apiClient.get(
                ApiEndpoints.ecomOrders,
                queryParameters: {ApiParameters.orderItemId: orderItemId},
              )
              as Map<String, dynamic>;
      final data = response['data'];
      final Map<String, dynamic> orderJson;
      if (data is List && data.isNotEmpty) {
        orderJson = Map<String, dynamic>.from(data.first);
      } else if (data is Map<String, dynamic>) {
        orderJson = data;
      } else {
        throw ApiException(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.orderNotFound,
          ),
        );
      }
      return EcommerceOrderDataModel.fromJson(orderJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
