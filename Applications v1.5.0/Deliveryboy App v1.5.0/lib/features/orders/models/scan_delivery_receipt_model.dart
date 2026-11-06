import 'return_order_model.dart';

/// Response of POST /scan_delivery_receipt — resolves a scanned QR code to
/// the full order detail payload for whichever order it belongs to.
///
/// [data] mirrors the shape of the channel-specific detail endpoint's own
/// `data` field — quick orders nest under an `order` key (matching
/// `order_by_id`), ecommerce orders are flat (matching `ecom_orders`) — so
/// the caller can hand it straight to [OrderDetailData.fromJson] /
/// [EcommerceOrderDataModel.fromJson] without a second API round trip.
class ScanDeliveryReceiptResponse {
  final String? message;
  final Map<String, dynamic>? data;

  const ScanDeliveryReceiptResponse({this.message, this.data});

  factory ScanDeliveryReceiptResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    Map<String, dynamic>? data;
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else if (rawData is List && rawData.isNotEmpty && rawData.first is Map) {
      data = Map<String, dynamic>.from(rawData.first as Map);
    }
    return ScanDeliveryReceiptResponse(
      message: json['message']?.toString(),
      data: data,
    );
  }

  /// The order's channel — 'quick' for a quick order; nested under `order`
  /// for the quick-order-shaped envelope, top-level for the ecommerce one.
  String? get channel {
    final d = data;
    if (d == null) return null;
    final order = d['order'];
    if (order is Map) return order['channel']?.toString();
    return d['channel']?.toString();
  }

  bool get isQuick => channel == 'quick';

  /// The sub-map actually holding the return request's fields — nested under
  /// `order` for the quick-order-shaped envelope, top-level otherwise. `null`
  /// when the scanned code isn't a return pickup.
  Map<String, dynamic>? get _returnData {
    final d = data;
    if (d == null) return null;
    final order = d['order'];
    if (order is Map && order['return_number'] != null) {
      return Map<String, dynamic>.from(order);
    }
    if (d['return_number'] != null) return d;
    return null;
  }

  /// Present when the scanned code belongs to a return pickup rather than a
  /// regular delivery — takes priority over [channel] when routing.
  String? get returnNumber => _returnData?['return_number']?.toString();

  /// The return request, ready to hand straight to the detail screen without
  /// a second `getReturnRequestById` round trip.
  ReturnRequestData? get returnRequestData {
    final rd = _returnData;
    return rd == null ? null : ReturnRequestData.fromJson(rd);
  }
}
