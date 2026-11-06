import 'package:customer/features/cart/models/delivery_type.dart';

class OrderDetailArgs {
  final String orderId;

  /// True when opened from the Ongoing tab/tracking flow — gates OTP
  /// visibility, since a completed order's OTP is no longer relevant.
  final bool isOngoing;

  /// True only when landing here straight off a delivered-order-tracking
  /// hand-off — plays a one-time attention pulse on the rating control so
  /// the customer notices it, instead of every normal visit to this screen.
  final bool highlightRating;

  const OrderDetailArgs({
    required this.orderId,
    this.isOngoing = false,
    this.highlightRating = false,
  });
}

class EcommerceOrderDetailArgs {
  final String orderItemId;

  /// True when opened from the Ongoing tab/tracking flow — gates OTP
  /// visibility, since a completed order's OTP is no longer relevant.
  final bool isOngoing;

  const EcommerceOrderDetailArgs({
    required this.orderItemId,
    this.isOngoing = false,
  });
}

class OrderSuccessArgs {
  final String orderId;

  /// Ecommerce channel's item-level id, from the place-order/payment
  /// response — needed to route "Track My Order" to EcommerceOrderDetailArgs.
  final String orderItemId;

  /// Quick-channel "Track My Order" routes to [RouteNames.orderTracking]
  /// for delivery, [RouteNames.orderDetail] for pickup (no live rider to
  /// track for a pickup order).
  final DeliveryType deliveryType;

  const OrderSuccessArgs({
    required this.orderId,
    this.orderItemId = '',
    this.deliveryType = DeliveryType.delivery,
  });
}
