/// Backend order status codes, shared across normal, ecommerce, and quick
/// order channels — mirrors the mapping documented in [OrderStatusLabels].
/// Ids 1,2,5,6,7,8 are shared by both channels; 3 (processing)/4 (shipped)
/// only occur for ecommerce orders; 9 (preparing)/10 (ready for pickup)/11
/// (pickup) only for quick orders.
enum OrderStatus {
  paymentPending(1),
  received(2),
  processing(3),
  shipped(4),
  outForDelivery(5),
  delivered(6),
  cancelled(7),
  returned(8),
  preparing(9),
  readyForPickup(10),
  pickup(11);

  const OrderStatus(this.id);

  final int id;

  /// String form, matching the `order_statuses` API's `id` field (e.g. `next.id`).
  String get value => id.toString();

  static OrderStatus? fromId(int? id) {
    for (final status in OrderStatus.values) {
      if (status.id == id) return status;
    }
    return null;
  }

  static OrderStatus? fromValue(String? value) =>
      fromId(int.tryParse(value ?? ''));

  /// Quick-order statuses where the delivery boy hasn't picked the order up
  /// yet — tracking should show delivery-boy ↔ store during these.
  static const _prePickupIds = {1, 2, 9, 10, 11};

  /// Whether the "Track Order" button/screen should be shown for
  /// [activeStatus]: any in-progress status, up to (not including) delivered
  /// — cancelled/returned orders have nothing left to track either.
  static bool isTrackable(int? activeStatus) {
    final status = fromId(activeStatus);
    if (status == null) return false;
    return status != delivered && status != cancelled && status != returned;
  }

  /// Whether [activeStatus] is still in the store-side leg of a quick order
  /// (before pickup) — used to pick delivery-boy↔store vs
  /// delivery-boy↔customer tracking on [OrderTrackingScreen].
  static bool isPrePickup(int? activeStatus) =>
      _prePickupIds.contains(activeStatus);
}
