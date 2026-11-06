import 'dart:convert';

import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/cart_recommendations_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:dio/dio.dart';

class CartRepository {
  final ApiClient _apiClient;

  CartRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Cart> getCart({
    String? latitude,
    String? longitude,
    String? addressId,
    // Omit to keep server's default ('delivery').
    DeliveryType? deliveryType,
  }) async {
    try {
      final lat = latitude ?? SettingsHiveBox.instance.userLatitude;
      final lng = longitude ?? SettingsHiveBox.instance.userLongitude;
      final cleanAddressId = addressId?.trim();
      final params = <String, dynamic>{
        ApiParameters.latitude: lat,
        ApiParameters.longitude: lng,
        if (cleanAddressId != null &&
            cleanAddressId.isNotEmpty &&
            cleanAddressId != 'null')
          ApiParameters.addressId: cleanAddressId,
        if (deliveryType != null)
          ApiParameters.deliveryType: deliveryType.apiValue,
      };
      final response = await _apiClient.get(
        ApiEndpoints.cart,
        queryParameters: params,
      );
      return Cart.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Guest cart — items stored locally; send variant_ids + quantities to get server pricing.
  /// [variantIds] and [quantities] are parallel lists (index 0 matches index 0).
  ///
  /// Add-on module: [items] (`[{variant_id, qty, addons}]`) replaces
  /// the CSV pair when the guest cart holds add-on lines, since the CSV pair
  /// can't carry a per-item answer list. Sent JSON-encoded as `items=`.
  Future<Cart> getGuestCart({
    required List<String> variantIds,
    required List<String> quantities,
    List<Map<String, dynamic>> items = const [],
    // Omit to keep server's default ('delivery').
    DeliveryType? deliveryType,
  }) async {
    try {
      final lat = SettingsHiveBox.instance.userLatitude;
      final lng = SettingsHiveBox.instance.userLongitude;
      final params = <String, dynamic>{
        ApiParameters.latitude: lat,
        ApiParameters.longitude: lng,
        if (items.isNotEmpty)
          ApiParameters.items: jsonEncode(items)
        else ...{
          ApiParameters.variantIds: variantIds.join(','),
          ApiParameters.quantities: quantities.join(','),
        },
        if (deliveryType != null)
          ApiParameters.deliveryType: deliveryType.apiValue,
      };
      final response = await _apiClient.get(
        ApiEndpoints.guestCart,
        queryParameters: params,
      );
      return Cart.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Returns the full cart payload (same shape as [getCart]) so callers can
  /// update state from the response without a separate get_cart call.
  ///
  /// Add-on module: [addons] is the `{id, qty}` list of chosen option
  /// ids (never group ids); qty is per unit of the dish. Omit for non-add-on
  /// products — a product with a required group is refused without it.
  Future<Cart> addToCart({
    required String productId,
    required String productVariantId,
    required int qty,
    List<AddonSelection>? addons,
    // Add-on module: lets the post-login merge add a guest add-on line
    // to the channel it was saved under, not whichever is active now.
    String? channel,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final params = <String, dynamic>{
        ApiParameters.productId: productId,
        ApiParameters.productVariantId: productVariantId,
        ApiParameters.qty: qty,
        ApiParameters.latitude: hive.userLatitude,
        ApiParameters.longitude: hive.userLongitude,
      };
      final response = await _apiClient.post(
        ApiEndpoints.cartAdd,
        queryParameters: params,
        data: _addonsBody(addons),
        options: channel == null
            ? null
            : Options(headers: {ApiParameters.channel: channel}),
      );
      return Cart.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Pass qty > 0 to update, qty = 0 to remove that item.
  /// Returns the full cart payload (same shape as [getCart]).
  ///
  /// Add-on module: pass the line's same [addons] array so the server
  /// knows *which* line of this product to hit when several exist.
  Future<Cart> removeFromCart({
    required String productId,
    required String productVariantId,
    int qty = 0,
    List<AddonSelection>? addons,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final params = <String, dynamic>{
        ApiParameters.productId: productId,
        ApiParameters.productVariantId: productVariantId,
        ApiParameters.qty: qty,
        ApiParameters.latitude: hive.userLatitude,
        ApiParameters.longitude: hive.userLongitude,
      };
      final response = await _apiClient.post(
        ApiEndpoints.cartRemove,
        queryParameters: params,
        data: _addonsBody(addons),
      );
      return Cart.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Add-on module: `addons` is an array of objects, which a query
  /// string can't carry, so it goes in the JSON body next to the existing
  /// query params. Null (no body) for non-add-on lines keeps the old request.
  Map<String, dynamic>? _addonsBody(List<AddonSelection>? addons) {
    if (addons == null || addons.isEmpty) return null;
    return {ApiParameters.addons: addons.map((a) => a.toJson()).toList()};
  }

  Future<String> clearCart() async {
    try {
      final params = <String, dynamic>{ApiParameters.isRemoveAll: '1'};
      final response = await _apiClient.post(
        ApiEndpoints.cartRemove,
        queryParameters: params,
      );
      final map = response as Map<String, dynamic>;
      return map['message']?.toString() ?? '';
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CartRecommendations> getCartRecommendations({
    String? latitude,
    String? longitude,
    String? productId,
    int crossSellLimit = 10,
    int crossSellOffset = 1,
    int upsellLimit = 10,
    int upsellOffset = 1,
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final params = <String, dynamic>{
        ApiParameters.latitude: latitude ?? hive.userLatitude,
        ApiParameters.longitude: longitude ?? hive.userLongitude,
        ApiParameters.crossSellLimit: crossSellLimit,
        ApiParameters.crossSellOffset: crossSellOffset,
        ApiParameters.upsellLimit: upsellLimit,
        ApiParameters.upsellOffset: upsellOffset,
        ApiParameters.productId: ?productId,
      };
      final response = await _apiClient.get(
        ApiEndpoints.cartRecommendations,
        queryParameters: params,
      );
      return CartRecommendations.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Merge guest cart into authenticated cart after login, or re-add order
  /// items (reorder).
  ///
  /// Add-on module: a channel whose basket holds any add-on line goes as
  /// `quick_items` / `ecommerce_items` in the JSON body (one object per line,
  /// plain lines included); a channel with none keeps the legacy CSV pair in
  /// the query. The server validates line by line and the first failure ends
  /// the call with the earlier lines already in the cart — callers should
  /// order lines so a refusal costs as little as possible.
  Future<String> bulkAddToCart({
    List<BulkCartItem> quickItems = const [],
    List<BulkCartItem> ecommerceItems = const [],
  }) async {
    try {
      final hive = SettingsHiveBox.instance;
      final quickAsItems = quickItems.any((i) => i.hasAddons);
      final ecommerceAsItems = ecommerceItems.any((i) => i.hasAddons);
      final params = <String, dynamic>{
        if (!quickAsItems) ...{
          ApiParameters.quickVariantIds: quickItems
              .map((i) => i.variantId)
              .join(','),
          ApiParameters.quickQuantities: quickItems
              .map((i) => i.qty)
              .join(','),
        },
        if (!ecommerceAsItems) ...{
          ApiParameters.ecommerceVariantIds: ecommerceItems
              .map((i) => i.variantId)
              .join(','),
          ApiParameters.ecommerceQuantities: ecommerceItems
              .map((i) => i.qty)
              .join(','),
        },
        ApiParameters.latitude: hive.userLatitude,
        ApiParameters.longitude: hive.userLongitude,
      };
      final body = <String, dynamic>{
        if (quickAsItems)
          ApiParameters.quickItems: quickItems.map((i) => i.toJson()).toList(),
        if (ecommerceAsItems)
          ApiParameters.ecommerceItems: ecommerceItems
              .map((i) => i.toJson())
              .toList(),
      };
      final response = await _apiClient.post(
        ApiEndpoints.guestCartBulkAddToCartWhileLogin,
        queryParameters: params,
        data: body.isEmpty ? null : body,
      );
      final map = response as Map<String, dynamic>;
      return map['message']?.toString() ?? '';
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
