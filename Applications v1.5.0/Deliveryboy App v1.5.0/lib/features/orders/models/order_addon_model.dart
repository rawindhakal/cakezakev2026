import 'package:deliveryboy/utils/extensions/num_extensions.dart';

// Add-on module: an order item's chosen options come back as an `addons`
// array — a priced snapshot of what the customer picked, names as they were
// when ordered. Items that are not add-on simply carry `addons: []` and
// `addon_total: 0`, so every field here is additive.

/// One chosen option on an order item (`addons[]`).
class OrderAddon {
  int? groupId;
  String? groupName;
  String? inputType;
  int? optionId;
  String? optionName;

  /// How many of this option, per unit of the dish.
  int? qty;
  double? unitPrice;

  /// How many of this option the group's free allowance covered.
  int? freeQty;

  /// What this option actually adds per unit of the dish, after the
  /// allowance.
  double? linePrice;

  /// 1 when the group's free allowance made it free.
  int? isFree;

  OrderAddon({
    this.groupId,
    this.groupName,
    this.inputType,
    this.optionId,
    this.optionName,
    this.qty,
    this.unitPrice,
    this.freeQty,
    this.linePrice,
    this.isFree,
  });

  OrderAddon.fromJson(Map<String, dynamic> json) {
    groupId = toSafeIntOrNull(json['group_id']);
    groupName = json['group_name']?.toString();
    inputType = json['input_type']?.toString();
    optionId = toSafeIntOrNull(json['option_id']);
    optionName = json['option_name']?.toString();
    qty = toSafeInt(json['qty'], 1);
    unitPrice = toSafeDoubleOrNull(json['unit_price']);
    freeQty = toSafeInt(json['free_qty']);
    linePrice = toSafeDoubleOrNull(json['line_price']);
    isFree = toSafeInt(json['is_free']);
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'group_name': groupName,
    'input_type': inputType,
    'option_id': optionId,
    'option_name': optionName,
    'qty': qty,
    'unit_price': unitPrice,
    'free_qty': freeQty,
    'line_price': linePrice,
    'is_free': isFree,
  };
}

/// Parses an `addons` array off an order item. Anything that isn't a list
/// (absent on non-add-on items) becomes empty.
List<OrderAddon> parseOrderAddons(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<String, dynamic>>().map(OrderAddon.fromJson).toList();
}

/// Readable label for one chosen option, in the receipt style
/// "2 × Olives +₹20". Free options carry no tag — only a positive
/// `line_price` adds a "+price" suffix.
String formatOrderAddon(OrderAddon addon, {required String currency}) {
  final qty = addon.qty ?? 1;
  final name = addon.optionName ?? '';
  final price = addon.linePrice ?? 0;
  return [
    qty > 1 ? '$qty × $name' : name,
    if (price > 0) '+$currency${price.trimmedFixed()}',
  ].join(' ');
}

/// Readable one-liner for an item's chosen options, in the receipt style
/// "Cheese burst +₹30, Paneer, 2 × Olives".
String formatOrderAddons(List<OrderAddon> addons, {required String currency}) =>
    addons.map((a) => formatOrderAddon(a, currency: currency)).join(', ');
