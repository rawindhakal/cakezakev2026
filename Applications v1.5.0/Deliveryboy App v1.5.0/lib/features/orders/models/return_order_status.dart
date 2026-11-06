enum ReturnOrderStatus {
  pending(1),
  approved(2),
  rejected(3),
  deliveryBoyAssigned(4),
  outForPickup(5),
  receivedFromCustomer(6),
  cancelled(7),
  returnToSeller(8);

  const ReturnOrderStatus(this.id);

  final int id;

  static ReturnOrderStatus fromId(int? id) {
    for (final status in ReturnOrderStatus.values) {
      if (status.id == id) return status;
    }
    return ReturnOrderStatus.pending;
  }
}
