import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/guest_cart_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CartEntry {
  final String variantId;
  final double price;
  final int quantity;
  final String imageUrl;

  const CartEntry({
    required this.variantId,
    required this.price,
    required this.quantity,
    this.imageUrl = '',
  });

  CartEntry copyWith({int? quantity}) => CartEntry(
    variantId: variantId,
    price: price,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl,
  );
}

class CartState {
  final Map<String, CartEntry> entries;

  /// Add-on module: every add-on cart line, keyed by [addonLineKey]
  /// (variant id + addon fingerprint). One variant can sit in the cart as
  /// several lines with different answers; [entries] keeps their summed
  /// count per variant (badge, totals), this keeps them apart.
  final Map<String, AddonCartLine> addonLines;

  const CartState({this.entries = const {}, this.addonLines = const {}});

  /// Add-on module: key for one add-on line in [addonLines].
  static String addonLineKey(
    String variantId,
    Iterable<AddonSelection> addons,
  ) => '$variantId|${addonFingerprint(addons)}';

  /// Add-on module: units of this variant held by add-on lines.
  int addonQtyFor(String variantId) => addonLines.values
      .where((l) => l.variantId == variantId)
      .fold<int>(0, (s, l) => s + l.qty);

  /// Add-on module: current qty of the line these answers land on
  /// (0 when no such line exists yet). Empty answers = the plain line, i.e.
  /// whatever of this variant no add-on line accounts for.
  int addonLineCount(String variantId, Iterable<AddonSelection> addons) {
    if (addons.isEmpty) {
      return (countFor(variantId) - addonQtyFor(variantId)).clamp(0, 1 << 31);
    }
    return addonLines[addonLineKey(variantId, addons)]?.qty ?? 0;
  }

  /// Add-on module: the answer sets of every cart line of this variant
  /// (an empty list = the plain line without answers).
  List<List<AddonSelection>> addonLinesFor(String variantId) {
    final lines = [
      for (final l in addonLines.values)
        if (l.variantId == variantId) l.addons,
    ];
    if (addonLineCount(variantId, const []) > 0) lines.add(const []);
    return lines;
  }

  /// Add-on module: guest-cart request for `guest_cart`. Without add-on
  /// lines it stays the legacy CSV pair; with any, every line goes through
  /// `items` (plain ones with `addons: []`) since the CSV pair can't hold a
  /// per-item answer list.
  ({
    List<String> variantIds,
    List<String> quantities,
    List<Map<String, dynamic>> items,
  })
  get guestCartRequest {
    if (addonLines.isEmpty) {
      return (
        variantIds: entries.keys.toList(),
        quantities: entries.values.map((e) => e.quantity.toString()).toList(),
        items: const [],
      );
    }
    final items = <Map<String, dynamic>>[
      for (final e in entries.values)
        if (e.quantity - addonQtyFor(e.variantId) > 0)
          {
            'variant_id': int.tryParse(e.variantId) ?? e.variantId,
            'qty': e.quantity - addonQtyFor(e.variantId),
            'addons': const <Map<String, dynamic>>[],
          },
      for (final l in addonLines.values) l.toGuestItem(),
    ];
    return (variantIds: const [], quantities: const [], items: items);
  }

  int get totalItems => entries.values.fold(0, (s, e) => s + e.quantity);
  double get totalPrice =>
      entries.values.fold(0.0, (s, e) => s + e.price * e.quantity);
  int countFor(String variantId) => entries[variantId]?.quantity ?? 0;

  /// Last 3 unique product image URLs for the floating cart bar preview.
  /// Oldest first, so the latest-added sits at the end (front of the stack).
  List<String> get previewImages {
    final urls = imageUrls.toList();
    return urls.length <= 3 ? urls : urls.sublist(urls.length - 3);
  }

  /// Every unique product image URL in the cart, in insertion order.
  Set<String> get imageUrls => entries.values
      .map((e) => e.imageUrl)
      .where((url) => url.isNotEmpty)
      .toSet();
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  bool get canAddMore {
    final limit = SettingsHiveBox.instance.maxCartItemsCount;
    return limit <= 0 || state.totalItems < limit;
  }

  void add(String variantId, double price, {String imageUrl = ''}) {
    final limit = SettingsHiveBox.instance.maxCartItemsCount;
    if (limit > 0 && state.totalItems >= limit) return;

    final map = Map<String, CartEntry>.from(state.entries);
    final current = map[variantId];
    map[variantId] = CartEntry(
      variantId: variantId,
      price: price,
      quantity: (current?.quantity ?? 0) + 1,
      imageUrl: current?.imageUrl.isNotEmpty == true
          ? current!.imageUrl
          : imageUrl,
    );
    emit(CartState(entries: map, addonLines: state.addonLines));
    _persistGuestCart(map);
  }

  /// Add-on module: adds one unit of a dish with these answers to the
  /// local cart. For guests this is the cart itself (the server only prices
  /// it via `guest_cart`); logged-in users go through cart/add instead.
  void addGuestAddonLine({
    required String productId,
    required String variantId,
    required double price,
    required List<AddonSelection> addons,
    String imageUrl = '',
  }) {
    final limit = SettingsHiveBox.instance.maxCartItemsCount;
    if (limit > 0 && state.totalItems >= limit) return;
    final map = Map<String, CartEntry>.from(state.entries);
    final current = map[variantId];
    map[variantId] = CartEntry(
      variantId: variantId,
      price: price,
      quantity: (current?.quantity ?? 0) + 1,
      imageUrl: current?.imageUrl.isNotEmpty == true
          ? current!.imageUrl
          : imageUrl,
    );
    final lines = Map<String, AddonCartLine>.from(state.addonLines);
    if (addons.isNotEmpty) {
      final key = CartState.addonLineKey(variantId, addons);
      final line = lines[key];
      lines[key] = line == null
          ? AddonCartLine(
              productId: productId,
              variantId: variantId,
              addons: addons,
              qty: 1,
            )
          : line.copyWith(qty: line.qty + 1);
    }
    emit(CartState(entries: map, addonLines: lines));
    _persistGuestCart(map, lines);
  }

  /// Add-on module: removes [count] units of the guest line with these
  /// answers (empty answers = the plain line of that variant).
  void removeGuestAddonLine({
    required String variantId,
    required List<AddonSelection> addons,
    int count = 1,
  }) {
    final map = Map<String, CartEntry>.from(state.entries);
    final current = map[variantId];
    if (current == null) return;
    final lines = Map<String, AddonCartLine>.from(state.addonLines);
    var removed = count;
    if (addons.isNotEmpty) {
      final key = CartState.addonLineKey(variantId, addons);
      final line = lines[key];
      if (line == null) return;
      removed = count.clamp(0, line.qty);
      if (line.qty - removed <= 0) {
        lines.remove(key);
      } else {
        lines[key] = line.copyWith(qty: line.qty - removed);
      }
    }
    final newQty = current.quantity - removed;
    if (newQty <= 0) {
      map.remove(variantId);
    } else {
      map[variantId] = current.copyWith(quantity: newQty);
    }
    emit(CartState(entries: map, addonLines: lines));
    _persistGuestCart(map, lines);
  }

  int _loadGeneration = 0;

  Future<void> loadFromApi() async {
    final generation = ++_loadGeneration;
    try {
      final cart = await CartRepository().getCart();
      // Discard stale response: a newer loadFromApi (e.g. from a channel
      // switch) started after this one and must win, regardless of which
      // network call actually resolves first.
      if (generation != _loadGeneration) return;
      final items = cart.data?.cart;
      seedFromApi(items ?? []);
    } on ApiException catch (e) {
      if (generation != _loadGeneration) return;
      // Backend responds with a non-1 status ("No item(s) found in users
      // cart") — not a real HTTP/API failure — whenever the cart is
      // genuinely empty (e.g. emptied from the website), so ApiClient's
      // status!=1 check throws here instead of just handing back an empty
      // list. Only treat it as empty when the HTTP call itself succeeded
      // (status 200/201); a real network/auth failure must leave the last
      // known cart alone instead of wiping it.
      if (e.statusCode == 200 || e.statusCode == 201) {
        seedFromApi(const []);
      } else {
        logDebug('CartCubit.loadFromApi error: $e');
      }
    } catch (e) {
      logDebug('CartCubit.loadFromApi error: $e');
    }
  }

  void seedFromApi(List<ProductDataModel> items) {
    final channel = SettingsHiveBox.instance.channel;
    final map = <String, CartEntry>{};
    final addonLines = <String, AddonCartLine>{};
    for (final item in items) {
      // Backend's /cart response is not reliably channel-scoped — drop
      // items belonging to the other channel so a mixed list never leaks
      // into the currently displayed channel's cart.
      if (item.salesChannel != null &&
          item.salesChannel != channel &&
          item.salesChannel != AppConstants.both) {
        continue;
      }
      final id =
          (item.variantId?.toString().isNotEmpty == true
              ? item.variantId.toString()
              : item.variants?.isNotEmpty == true
              ? item.variants!.first.id?.toString()
              : null) ??
          '';
      if (id.isEmpty) continue;
      final qty = item.variants?.isNotEmpty == true
          ? (item.variants!.first.quantity ?? 0)
          : 0;
      if (qty <= 0) continue;
      // Add-on module: the same variant can come back as several lines
      // (one per set of answers) — sum them so the product's ADD button
      // shows the total instead of whichever line happened to come last.
      final existingQty = map[id]?.quantity ?? 0;
      if (item.isAddonLine) {
        final addons = item.addonSelections;
        addonLines[CartState.addonLineKey(id, addons)] = AddonCartLine(
          productId: item.id?.toString() ?? '',
          variantId: id,
          addons: addons,
          qty: qty,
        );
      }
      map[id] = CartEntry(
        variantId: id,
        price: (item.discountedPrice != null && item.discountedPrice! > 0)
            ? item.discountedPrice!
            : (item.price ?? 0),
        quantity: existingQty + qty,
        imageUrl: item.variants?.isNotEmpty == true
            ? (item.variants!.first.image ?? item.images?.coverUrl ?? '')
            : (item.images?.coverUrl ?? ''),
      );
    }
    // Keep the local insertion order for items we already have and append
    // only new ones — the server's order differs, and re-seeding (post-add
    // sync, 30s poll) would otherwise reshuffle previewImages, replaying the
    // floating cart bar's image fly-in/out for nothing.
    final ordered = <String, CartEntry>{
      for (final id in state.entries.keys)
        if (map.containsKey(id)) id: map[id]!,
    }..addAll(map);
    emit(CartState(entries: ordered, addonLines: addonLines));
  }

  void clear() {
    GuestCartHiveBox.instance.clearChannel(SettingsHiveBox.instance.channel);
    emit(const CartState());
  }

  /// Clears guest cart for ALL channels (called after login sync).
  void clearAllGuestData() {
    GuestCartHiveBox.instance.clearAll();
    emit(const CartState());
  }

  /// Switch displayed cart when user toggles quick ↔ ecommerce on home screen.
  /// No-op for logged-in users (server handles their cart via [loadFromApi]).
  void switchChannel(String channel) {
    if (AuthHiveBox.instance.isLoggedIn) return;
    final map = _loadEntriesFromHive(channel);
    emit(CartState(entries: map, addonLines: _loadAddonLinesFromHive(channel)));
  }

  /// Drops the currently displayed cart without touching persisted storage.
  /// Call right after a channel switch for logged-in users so the old
  /// channel's items don't linger on screen while [loadFromApi] is in flight.
  void resetForChannelSwitch() => emit(const CartState());

  /// Force a variant's quantity to an exact value (used to revert an
  /// optimistic add/remove when the server sync call fails).
  void setQuantity(
    String variantId,
    double price,
    int quantity, {
    String imageUrl = '',
  }) {
    final map = Map<String, CartEntry>.from(state.entries);
    if (quantity <= 0) {
      map.remove(variantId);
    } else {
      final current = map[variantId];
      map[variantId] = CartEntry(
        variantId: variantId,
        price: price,
        quantity: quantity,
        imageUrl: current?.imageUrl.isNotEmpty == true
            ? current!.imageUrl
            : imageUrl,
      );
    }
    emit(CartState(entries: map, addonLines: state.addonLines));
    _persistGuestCart(map);
  }

  void remove(String variantId, double price) {
    final map = Map<String, CartEntry>.from(state.entries);
    final current = map[variantId];
    if (current == null) return;
    final newQty = current.quantity - 1;
    if (newQty <= 0) {
      map.remove(variantId);
    } else {
      map[variantId] = current.copyWith(quantity: newQty);
    }
    emit(CartState(entries: map, addonLines: state.addonLines));
    _persistGuestCart(map);
  }

  /// Drops the entire line item, regardless of its current quantity.
  void removeAll(String variantId) {
    final map = Map<String, CartEntry>.from(state.entries);
    if (map.remove(variantId) == null) return;
    // Add-on module: the whole variant is gone, so are its add-on lines.
    final addonLines = Map<String, AddonCartLine>.from(state.addonLines)
      ..removeWhere((_, l) => l.variantId == variantId);
    emit(CartState(entries: map, addonLines: addonLines));
    _persistGuestCart(map, addonLines);
  }

  /// Load guest cart from Hive on app start when user is not logged in.
  void loadGuestCartFromHive() {
    final channel = SettingsHiveBox.instance.channel;
    final map = _loadEntriesFromHive(channel);
    if (map.isNotEmpty) {
      emit(
        CartState(entries: map, addonLines: _loadAddonLinesFromHive(channel)),
      );
    }
  }

  /// Add-on module: guest add-on lines saved for [channel].
  Map<String, AddonCartLine> _loadAddonLinesFromHive(String channel) {
    final lines = <String, AddonCartLine>{};
    for (final raw in GuestCartHiveBox.instance.loadAddonLines(channel)) {
      final line = AddonCartLine.fromJson(raw);
      if (line == null) continue;
      lines[CartState.addonLineKey(line.variantId, line.addons)] = line;
    }
    return lines;
  }

  Map<String, CartEntry> _loadEntriesFromHive(String channel) {
    final raw = GuestCartHiveBox.instance.loadEntries(channel);
    if (raw.isEmpty) return {};
    final map = <String, CartEntry>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      map[entry.key] = CartEntry(
        variantId: v['variantId'] as String? ?? entry.key,
        price: (v['price'] as num?)?.toDouble() ?? 0.0,
        quantity: v['quantity'] as int? ?? 1,
        imageUrl: v['imageUrl'] as String? ?? '',
      );
    }
    return map;
  }

  void _persistGuestCart(
    Map<String, CartEntry> entries, [
    Map<String, AddonCartLine>? addonLines,
  ]) {
    if (AuthHiveBox.instance.isLoggedIn) return;
    // Add-on module: keep the guest's add-on lines next to the entries.
    GuestCartHiveBox.instance.saveAddonLines(
      (addonLines ?? state.addonLines).values.map((l) => l.toJson()).toList(),
      SettingsHiveBox.instance.channel,
    );
    final raw = entries.map(
      (k, e) => MapEntry(k, {
        'variantId': e.variantId,
        'price': e.price,
        'quantity': e.quantity,
        'imageUrl': e.imageUrl,
      }),
    );
    GuestCartHiveBox.instance.saveEntries(
      raw,
      SettingsHiveBox.instance.channel,
    );
  }
}
