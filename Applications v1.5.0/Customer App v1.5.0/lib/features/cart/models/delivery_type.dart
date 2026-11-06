/// Fulfillment method for a cart/order: `delivery` (to an address) or
/// `pickup` (customer collects from the browsing zone's fixed store).
///
/// Enum member names match the API's `delivery_type` param/response value
/// verbatim (`apiValue` just reads `name`), so there's one source of truth
/// instead of 'delivery'/'pickup' string literals scattered across repos,
/// cubits and screens.
enum DeliveryType {
  delivery,
  pickup;

  String get apiValue => name;

  static DeliveryType fromApiValue(String? value) =>
      value == pickup.apiValue ? DeliveryType.pickup : DeliveryType.delivery;
}
