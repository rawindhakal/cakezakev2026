import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/utils/json_parsers.dart';

// Add-on module: models for CakeZake 1.5.0 add-on addons.
//
// Three levels: product → group → option. An add-on product (`is_food: 1`)
// carries `addon_groups` on product detail; the customer's answers travel on
// the cart line as `addons: [{id, qty}]` (option ids only, never group ids)
// and come back on cart lines / order items as a priced snapshot
// ([CartAddon]). Products that are not add-on simply have no groups,
// `addons: []` and `addon_total: 0`, so every field here is additive.

/// Add-on module: one question on an add-on product ("Choose crust").
/// Read from `addon_groups[]` on `GET /customer/product_by_id`.
class AddonGroup {
  int? id;
  String? name;

  /// Backend-written, translated rules sentence ("Required · Select any 1
  /// option"). Rendered as-is under [name] — never composed client-side so
  /// it can't contradict the real rules.
  String? selectionText;

  /// "radio" (single choice) or "checkbox" (multiple).
  String? inputType;
  int? isRequired;

  /// Fewest *different* options that must be picked. 0 = none.
  int? minSelect;

  /// Most *different* options that may be picked. 0 = no limit.
  int? maxSelect;

  /// How many picks cost nothing — applied to the most expensive picks
  /// first. 0 = everything is charged.
  int? freeLimit;

  /// Repeats of the *same* option allowed per unit of the dish. 1 = plain
  /// tick, above 1 = stepper.
  int? maxQtyPerOption;
  List<AddonOption>? options;

  AddonGroup({
    this.id,
    this.name,
    this.selectionText,
    this.inputType,
    this.isRequired,
    this.minSelect,
    this.maxSelect,
    this.freeLimit,
    this.maxQtyPerOption,
    this.options,
  });

  bool get isRadio => inputType == 'radio';
  bool get required => isRequired == 1;

  /// Add-on module: `max_select: 0` means unlimited, not "none".
  bool get hasMaxSelect => !isRadio && (maxSelect ?? 0) > 0;

  AddonGroup.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    selectionText = parseString(json['selection_text']);
    inputType = parseString(json['input_type']);
    isRequired = parseInt(json['is_required']) ?? 0;
    minSelect = parseInt(json['min_select']) ?? 0;
    maxSelect = parseInt(json['max_select']) ?? 0;
    freeLimit = parseInt(json['free_limit']) ?? 0;
    maxQtyPerOption = parseInt(json['max_qty_per_option']) ?? 1;
    final rawOptions = json['options'];
    if (rawOptions is List) {
      options = rawOptions
          .whereType<Map<String, dynamic>>()
          .map(AddonOption.fromJson)
          .toList();
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'selection_text': selectionText,
    'input_type': inputType,
    'is_required': isRequired,
    'min_select': minSelect,
    'max_select': maxSelect,
    'free_limit': freeLimit,
    'max_qty_per_option': maxQtyPerOption,
    'options': options?.map((o) => o.toJson()).toList(),
  };
}

/// Add-on module: one answer within a group ("Cheese burst"). Anything
/// the client receives can be ordered — the store drops unservable options.
class AddonOption {
  /// The id sent back in the `addons` array on add-to-cart.
  int? id;
  String? name;

  /// What one adds to the line at this store, after any offer. 0 = free.
  double? price;

  /// Price before any offer; equals [price] when there is no offer.
  double? originalPrice;
  double? chargePrice;
  int? inStock;

  /// Same scale as the product's `product_type` (1 = veg, 2 = non-veg, …);
  /// drives the [ProductTypeIcon] before the option name. 0 = no icon.
  int? productType;

  /// Optional thumbnail shown before the option name; empty = none.
  String? image;

  /// Stepper's upper bound per unit of the dish — the group's
  /// `max_qty_per_option`, lowered to shelf stock for linked options.
  int? maxQty;

  /// 1 = this option is a real catalogue product (e.g. "Add a Coke").
  int? isLinked;
  int? linkedVariantId;

  AddonOption({
    this.id,
    this.name,
    this.price,
    this.originalPrice,
    this.chargePrice,
    this.inStock,
    this.productType,
    this.image,
    this.maxQty,
    this.isLinked,
    this.linkedVariantId,
  });

  bool get hasOffer => (originalPrice ?? 0) > (price ?? 0);
  bool get isFree => (price ?? 0) <= 0;
  bool get linked => isLinked == 1;
  bool get hasImage => (image ?? '').isNotEmpty;

  AddonOption.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    price = parseDouble(json['price']);
    originalPrice = parseDouble(json['original_price']);
    chargePrice = parseDouble(json['charge_price']);
    inStock = parseInt(json['in_stock']) ?? 1;
    productType = parseInt(json['product_type']) ?? 0;
    image = parseString(json['image']);
    maxQty = parseInt(json['max_qty']) ?? 1;
    isLinked = parseInt(json['is_linked']) ?? 0;
    linkedVariantId = parseInt(json['linked_variant_id']);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'original_price': originalPrice,
    'charge_price': chargePrice,
    'in_stock': inStock,
    'product_type': productType,
    'image': image,
    'max_qty': maxQty,
    'is_linked': isLinked,
    'linked_variant_id': linkedVariantId,
  };
}

/// Add-on module: one chosen option as sent to `cart/add` and
/// `cart/remove` — `{id, qty}`, where qty is per unit of the dish.
class AddonSelection {
  final int id;
  final int qty;

  const AddonSelection({required this.id, required this.qty});

  Map<String, dynamic> toJson() => {'id': id, 'qty': qty};
}

/// Add-on module: one chosen option as returned on a cart line or an
/// order item (`addons[]`). On orders this is a snapshot — names stay as
/// they were when ordered.
class CartAddon {
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

  /// 1 when the group's free allowance made it free (not the admin's
  /// "free option" setting, which reaches the client as price 0).
  int? isFree;

  /// 0 if the option stopped being servable after it was added (cart only).
  int? available;
  int? linkedVariantId;

  CartAddon({
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
    this.available,
    this.linkedVariantId,
  });

  bool get isUnavailable => available == 0;
  bool get coveredByFreeAllowance => isFree == 1;

  CartAddon.fromJson(Map<String, dynamic> json) {
    groupId = parseInt(json['group_id']);
    groupName = parseString(json['group_name']);
    inputType = parseString(json['input_type']);
    optionId = parseInt(json['option_id']);
    optionName = parseString(json['option_name']);
    qty = parseInt(json['qty']) ?? 1;
    unitPrice = parseDouble(json['unit_price']);
    freeQty = parseInt(json['free_qty']) ?? 0;
    linePrice = parseDouble(json['line_price']);
    isFree = parseInt(json['is_free']) ?? 0;
    available = parseInt(json['available']) ?? 1;
    linkedVariantId = parseInt(json['linked_variant_id']);
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
    'available': available,
    'linked_variant_id': linkedVariantId,
  };

  /// Add-on module: the same `{id, qty}` pair this line was added
  /// with — `cart/remove` needs it to know which line of the product to hit.
  AddonSelection? toSelection() {
    final id = optionId;
    if (id == null) return null;
    return AddonSelection(id: id, qty: qty ?? 1);
  }
}

/// Add-on module: parses an `addons` array off a cart line / order item.
/// Anything that isn't a list (absent on non-add-on lines) becomes empty.
List<CartAddon> parseCartAddons(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<String, dynamic>>().map(CartAddon.fromJson).toList();
}

/// Add-on module: order-independent key for a set of selections. The
/// backend sorts selections before fingerprinting a cart line, so two lines
/// of the same variant differ only by this — mirrored here to find the
/// existing line a new selection lands on.
String addonFingerprint(Iterable<AddonSelection> selections) {
  final parts = selections.map((s) => '${s.id}x${s.qty}').toList()..sort();
  return parts.join(',');
}

/// Add-on module: readable label for one chosen option, in the receipt
/// style "2 × Olives +₹20". Free options carry no tag — only a positive
/// `line_price` adds a "+price" suffix.
String formatCartAddon(
  CartAddon addon, {
  required String currency,
  int decimalPoint = 2,
}) {
  final qty = addon.qty ?? 1;
  final name = addon.optionName ?? '';
  final price = addon.linePrice ?? 0;
  return [
    qty > 1 ? '$qty × $name' : name,
    if (price > 0) '+$currency${price.formatPrice(decimalPoint)}',
  ].join(' ');
}

/// Add-on module: readable one-liner for a line's chosen options, in
/// the receipt style "Cheese burst +₹30, Paneer, 2 × Olives".
String formatCartAddons(
  List<CartAddon> addons, {
  required String currency,
  int decimalPoint = 2,
}) {
  return addons
      .map(
        (a) =>
            formatCartAddon(a, currency: currency, decimalPoint: decimalPoint),
      )
      .join(', ');
}

/// Add-on module: one add-on line of the cart as the app tracks it — the
/// dish, its answers and how many of that exact combination. For logged-in
/// users it mirrors the server cart; for guests it is the local cart line
/// (persisted to Hive) that `guest_cart`'s `items` parameter and the
/// post-login merge are built from.
class AddonCartLine {
  final String productId;
  final String variantId;
  final List<AddonSelection> addons;
  final int qty;

  const AddonCartLine({
    required this.productId,
    required this.variantId,
    required this.addons,
    required this.qty,
  });

  AddonCartLine copyWith({int? qty}) => AddonCartLine(
    productId: productId,
    variantId: variantId,
    addons: addons,
    qty: qty ?? this.qty,
  );

  /// Shape of one entry in `guest_cart`'s `items` parameter.
  Map<String, dynamic> toGuestItem() => {
    'variant_id': int.tryParse(variantId) ?? variantId,
    'qty': qty,
    'addons': addons.map((a) => a.toJson()).toList(),
  };

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'variantId': variantId,
    'qty': qty,
    'addons': addons.map((a) => a.toJson()).toList(),
  };

  BulkCartItem toBulkItem() =>
      BulkCartItem(variantId: variantId, qty: qty, addons: addons);

  static AddonCartLine? fromJson(Map<String, dynamic> json) {
    final variantId = json['variantId']?.toString() ?? '';
    final qty = parseInt(json['qty']) ?? 0;
    if (variantId.isEmpty || qty <= 0) return null;
    final rawAddons = json['addons'];
    final addons = <AddonSelection>[
      if (rawAddons is List)
        for (final a in rawAddons.whereType<Map>())
          if (parseInt(a['id']) != null)
            AddonSelection(
              id: parseInt(a['id'])!,
              qty: parseInt(a['qty']) ?? 1,
            ),
    ];
    return AddonCartLine(
      productId: json['productId']?.toString() ?? '',
      variantId: variantId,
      addons: addons,
      qty: qty,
    );
  }
}

/// Add-on module: one line of a `bulk_add_to_cart_items` basket. A
/// channel whose basket holds any add-on line is sent as `quick_items` /
/// `ecommerce_items` (one object per line); otherwise it keeps the legacy
/// positional CSV pair, which can't carry a per-line answer list.
class BulkCartItem {
  final String variantId;
  final int qty;
  final List<AddonSelection> addons;

  const BulkCartItem({
    required this.variantId,
    required this.qty,
    this.addons = const [],
  });

  bool get hasAddons => addons.isNotEmpty;

  /// `addons` here is option ids with an id repeated to mean two of it
  /// (`[1, 9, 9]`), not the `{id, qty}` objects `cart/add` takes. qty is
  /// still per unit of the dish.
  Map<String, dynamic> toJson() => {
    'variant_id': int.tryParse(variantId) ?? variantId,
    'qty': qty,
    if (addons.isNotEmpty)
      'addons': [
        for (final a in addons)
          for (var i = 0; i < a.qty; i++) a.id,
      ],
  };
}
