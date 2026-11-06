import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart'
    hide Order;
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart'
    as status_model
    show OrderStatus;
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/models/scan_delivery_receipt_model.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Data-access layer for quick, ecommerce, and return orders — talks to [ApiClient]
/// and maps responses to models; lets [ApiException] propagate to callers.
class OrderRepository {
  final ApiClient _apiClient;

  /// Max distance (metres) OSRM may snap an input point to a road before
  /// the route is considered unusable.
  static const double _maxRouteSnapMeters = 200;

  OrderRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// GET /order_by_id — fetch single order detail.
  Future<OrderDetail> getOrderById(String orderId) async {
    final response = await _apiClient.get(
      ApiEndpoints.orderById,
      queryParameters: {ApiParameters.orderId: orderId},
    );
    return OrderDetail.fromJson(response as Map<String, dynamic>);
  }

  /// POST /scan_delivery_receipt — resolves a scanned QR [code] to its order id.
  Future<ScanDeliveryReceiptResponse> scanDeliveryReceipt(String code) async {
    final response = await _apiClient.post(
      ApiEndpoints.scanDeliveryReceipt,
      data: {ApiParameters.code: code},
    );
    return ScanDeliveryReceiptResponse.fromJson(response as Map<String, dynamic>);
  }

  /// GET /return_request_by_id — fetch single return request detail.
  Future<ReturnDetailResponse> getReturnRequestById(
    String returnRequestId,
  ) async {
    final response = await _apiClient.get(
      ApiEndpoints.returnRequests,
      queryParameters: {'return_request_id': returnRequestId},
    );
    return ReturnDetailResponse.fromJson(response as Map<String, dynamic>);
  }

  /// GET /return_requests — paginated list with optional filters.
  Future<PaginatedResponse<ReturnRequestData>> getReturnOrders({
    String? status,
    String? search,
    String? startDate,
    String? endDate,
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    final params = <String, dynamic>{
      ApiParameters.offset: offset,
      ApiParameters.limit: limit,
      if (status != null && status.isNotEmpty) ApiParameters.status: status,
      if (search != null && search.isNotEmpty) ApiParameters.search: search,
      if (startDate != null && startDate.isNotEmpty)
        ApiParameters.startDate: startDate,
      if (endDate != null && endDate.isNotEmpty) ApiParameters.endDate: endDate,
    };

    final response = await _apiClient.get(
      ApiEndpoints.returnRequests,
      queryParameters: params,
    );
    return PaginatedResponse.fromJson(
      response as Map<String, dynamic>,
      ReturnRequestData.fromJson,
    );
  }

  /// GET /orders — paginated list with optional filters.
  Future<PaginatedResponse<OrderData>> getOrders({
    String? status,
    String? search,
    String? startDeliveryDate,
    String? endDeliveryDate,
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    final params = <String, dynamic>{
      ApiParameters.offset: offset,
      ApiParameters.limit: limit,
      if (status != null && status.isNotEmpty) ApiParameters.status: status,
      if (search != null && search.isNotEmpty) ApiParameters.search: search,
      if (startDeliveryDate != null && startDeliveryDate.isNotEmpty)
        ApiParameters.startDate: startDeliveryDate,
      if (endDeliveryDate != null && endDeliveryDate.isNotEmpty)
        ApiParameters.endDate: endDeliveryDate,
    };

    final response = await _apiClient.get(
      ApiEndpoints.orders,
      queryParameters: params,
    );
    return PaginatedResponse.fromJson(
      response as Map<String, dynamic>,
      OrderData.fromJson,
    );
  }

  /// GET /order_statuses — fetch available statuses for a given order.
  Future<status_model.OrderStatus> getOrderStatuses({String? channel}) async {
    final queryParams = <String, dynamic>{};
    if (channel != null) {
      queryParams['channel'] = channel;
    }
    final response = await _apiClient.get(
      ApiEndpoints.orderStatuses,
      queryParameters: queryParams,
    );
    return status_model.OrderStatus.fromJson(response as Map<String, dynamic>);
  }

  /// POST /update_status — update order status.
  Future<void> updateOrderStatus({
    required String orderId,
    required String orderStatus,
    String? otp,
  }) async {
    await _apiClient.post(
      ApiEndpoints.updateStatus,
      data: {
        ApiParameters.orderId: orderId,
        ApiParameters.statusId: orderStatus,
        ApiParameters.otp: ?otp,
      },
    );
  }

  /// POST /update_item_status — update ecommerce order item status.
  Future<void> updateOrderItemStatus({
    required String orderItemId,
    required String orderStatus,
    String? otp,
  }) async {
    await _apiClient.post(
      ApiEndpoints.updateItemStatus,
      data: {
        ApiParameters.orderItemId: orderItemId,
        ApiParameters.statusId: orderStatus,
        ApiParameters.otp: ?otp,
      },
    );
  }

  /// POST /return_request_status_update — update return request order status.
  Future<void> updateReturnRequestOrderStatus({
    required String returnRequestId,
    required String orderStatus,
  }) async {
    await _apiClient.post(
      ApiEndpoints.returnRequestStatusUpdate,
      data: {
        ApiParameters.id: returnRequestId,
        ApiParameters.status: orderStatus,
      },
    );
  }

  /// POST /manage_live_tracking — manage live tracking of order.
  Future<void> orderLiveTracking({
    required String orderId,
    required String orderStatus,
    required String latitude,
    required String longitude,
  }) async {
    await _apiClient.post(
      ApiEndpoints.manageLiveTracking,
      data: {
        ApiParameters.orderId: orderId,
        ApiParameters.orderStatus: orderStatus,
        ApiParameters.latitude: latitude,
        ApiParameters.longitude: longitude,
      },
    );
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
      // OSRM snaps each input to the nearest road. A far snap (bad/mock GPS,
      // off-road point) yields a route that starts nowhere near the marker,
      // so drop it and let the caller fall back to the direct line.
      final waypoints = response.data['waypoints'] as List?;
      final tooFar = waypoints?.any(
        (w) => ((w['distance'] as num?) ?? 0) > _maxRouteSnapMeters,
      );
      if (tooFar ?? false) return null;
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

  /// GET /ecom_orders — ecommerce order items with offset/limit pagination.
  Future<PaginatedResponse<EcommerceOrderDataModel>> getEcommerceOrders({
    int offset = 0,
    int limit = AppConfig.pageLimit,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.ecomOrders,
      queryParameters: {
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        if (startDate != null && startDate.isNotEmpty)
          ApiParameters.startDate: startDate,
        if (endDate != null && endDate.isNotEmpty)
          ApiParameters.endDate: endDate,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PaginatedResponse.fromJson(
      response as Map<String, dynamic>,
      EcommerceOrderDataModel.fromJson,
    );
  }

  /// GET /ecom_orders?order_item_id — fetch ecommerce order item detail.
  Future<EcommerceOrderDataModel> getEcommerceOrderDetail(
    String orderItemId,
  ) async {
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
  }
}
