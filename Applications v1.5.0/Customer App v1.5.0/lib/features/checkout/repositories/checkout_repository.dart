import 'package:customer/features/gifting/gift_store.dart';
import 'package:dio/dio.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/features/cart/models/delivery_type.dart';

class CheckoutRepository {
  final ApiClient _apiClient;

  CheckoutRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> placeOrder({
    // Required for delivery; optional for pickup (doc: if sent, only
    // name/mobile are pulled from it for the Bill To, the store is still the
    // fulfillment point).
    String? addressId,
    required String paymentMethod,
    String? promoCodeId,
    String? walletUsed,
    String? walletBalance,
    String? orderNote,
    Map<String, String>? prescriptions,
    // Null for pickup — no shipping address exists to compare against, so
    // the key is omitted from the payload entirely (doc: ignored for pickup).
    bool? billingSameAsShipping,
    String? billingName,
    String? billingMobile,
    String? billingAddress,
    String? billingCity,
    String? billingPincode,
    String? billingCountry,
    String? billingState,
    int? billingRegionId,
    // Buyer tax registration of whichever party is billed (shipping address
    // when billing_same_as_shipping=1, the typed billing address otherwise).
    // Typed on the order form; never stored on an address.
    String? buyerTaxNumber,
    String? buyerBusinessName,
    // Omit to keep server's default ('delivery').
    DeliveryType? deliveryType,
    // Required for delivery; omitted for pickup — the pickup store is a
    // fixed point, not the customer's location.
    String? latitude,
    String? longitude,
  }) async {
    try {
      final data = <String, dynamic>{
        if (addressId != null && addressId.isNotEmpty)
          ApiParameters.addressId: addressId,
        ApiParameters.paymentMethod: paymentMethod,
        if (deliveryType != null)
          ApiParameters.deliveryType: deliveryType.apiValue,
        if (latitude != null && latitude.isNotEmpty)
          ApiParameters.latitude: latitude,
        if (longitude != null && longitude.isNotEmpty)
          ApiParameters.longitude: longitude,
        if (promoCodeId != null && promoCodeId != '0')
          ApiParameters.promoCodeId: promoCodeId,
        if (walletUsed != null && walletUsed != '0')
          ApiParameters.walletUsed: walletUsed,
        if (walletBalance != null && (double.tryParse(walletBalance) ?? 0) != 0)
          ApiParameters.walletBalance: walletBalance,
        if (orderNote != null && orderNote.isNotEmpty)
          ApiParameters.orderNote: orderNote,
        // Gifting: recipient, delivery date/slot, card message, personalisation.
        ...GiftStore.instance.fields,
        // Sent as typed (server uppercases + strips spaces, then validates
        // against the billed country and refuses BEFORE writing anything, so
        // a bad number never leaves a stray order). Omitted when empty: a
        // consumer order's payload stays identical to older app builds.
        if (buyerTaxNumber != null && buyerTaxNumber.isNotEmpty)
          ApiParameters.buyerTaxNumber: buyerTaxNumber,
        if (buyerBusinessName != null && buyerBusinessName.isNotEmpty)
          ApiParameters.buyerBusinessName: buyerBusinessName,
        if (billingSameAsShipping != null)
          ApiParameters.billingSameAsShipping: billingSameAsShipping
              ? '1'
              : '0',
        // Sent whenever a billing address was actually filled — either the
        // delivery-mode override (billingSameAsShipping == false) or
        // pickup's manually-typed address (billingSameAsShipping omitted,
        // no address_id, so this doubles as the required pickup address).
        if (billingSameAsShipping == false || billingName != null) ...{
          ApiParameters.billingName: billingName ?? '',
          ApiParameters.billingMobile: billingMobile ?? '',
          ApiParameters.billingAddress: billingAddress ?? '',
          ApiParameters.billingCity: billingCity ?? '',
          ApiParameters.billingPincode: billingPincode ?? '',
          ApiParameters.billingCountry: billingCountry ?? '',
          ApiParameters.billingState: billingState ?? '',
          ApiParameters.billingRegionId: (billingRegionId ?? '').toString(),
        },
      };

      // With prescription files attached, switch to multipart. Each file is
      // keyed by its product variant id — `prescription[<variant_id>]`.
      if (prescriptions != null && prescriptions.isNotEmpty) {
        for (final entry in prescriptions.entries) {
          data['${ApiParameters.prescription}[${entry.key}]'] =
              await MultipartFile.fromFile(
                entry.value,
                filename: entry.value.split('/').last,
              );
        }
        final response = await _apiClient.upload(
          ApiEndpoints.placeOrder,
          formData: FormData.fromMap(data),
        );
        return response as Map<String, dynamic>;
      }

      final response = await _apiClient.post(
        ApiEndpoints.placeOrder,
        data: data,
      );
      // The gift details belong to this order only.
      GiftStore.instance.clearOrder();
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
