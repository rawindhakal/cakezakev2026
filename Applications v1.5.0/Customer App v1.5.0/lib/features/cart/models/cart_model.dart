import 'package:customer/commons/models/additional_charges_model.dart';
import 'package:customer/commons/models/delivery_charges_model.dart';
import 'package:customer/commons/models/surge_charges_model.dart';
import 'package:customer/commons/models/tax_charges_model.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/json_parsers.dart';

class Cart {
  int? status;
  String? message;
  CartData? data;
  int? total;

  Cart({this.status, this.message, this.data, this.total});

  Cart.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? CartData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
    total = parseInt(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['total'] = total;
    return data;
  }
}

class CartData {
  int? codAllowed;
  String? productVariantId;
  String? quantity;
  String? distance;
  String? timeToDeliver;
  String? estimatedDeliveryDate;
  String? unlockMessage;
  String? unlockPromoCode;
  int? unlockPromoCodeId;
  int? isDeliverableAddress;
  DeliveryCharges? deliveryCharges;
  List<SurgeCharges>? surgeCharges;
  List<AdditionalCharges>? zoneAdditionalCharges;
  double? totalAmount;
  double? userBalance;
  double? subTotal;
  double? savedAmount;
  double? minimumOrderAmount;
  List<ProductDataModel>? cart;
  List<AdditionalCharges>? additionalCharges;
  List<TaxCharges>? taxBreakdown;
  String? currency;
  int? decimalPoint;

  // Self-pickup fields (added alongside delivery, both optional — absent /
  // null on responses from before self-pickup existed).
  /// Mode this cart was actually priced in ('delivery' | 'pickup'); server
  /// falls back to whichever mode the store offers if the requested one
  /// isn't available, so always read this rather than assuming the request.
  String? deliveryType;
  int? deliveryAvailable;
  int? pickupAvailable;
  CartPickupInfo? pickup;

  CartData({
    this.codAllowed,
    this.productVariantId,
    this.quantity,
    this.distance,
    this.timeToDeliver,
    this.estimatedDeliveryDate,
    this.unlockMessage,
    this.unlockPromoCode,
    this.unlockPromoCodeId,
    this.isDeliverableAddress,
    this.deliveryCharges,
    this.surgeCharges,
    this.zoneAdditionalCharges,
    this.totalAmount,
    this.userBalance,
    this.subTotal,
    this.savedAmount,
    this.minimumOrderAmount,
    this.cart,
    this.additionalCharges,
    this.taxBreakdown,
    this.currency,
    this.decimalPoint,
    this.deliveryType,
    this.deliveryAvailable,
    this.pickupAvailable,
    this.pickup,
  });

  CartData.fromJson(Map<String, dynamic> json) {
    codAllowed = parseInt(json['cod_allowed']);
    productVariantId = parseString(json['product_variant_id']);
    quantity = parseString(json['quantity']);
    distance = parseString(json['distance']);
    timeToDeliver = parseString(json['time_to_deliver']);
    estimatedDeliveryDate = parseString(json['estimated_delivery_date']);
    unlockMessage = parseString(json['unlock_message']);
    unlockPromoCode = parseString(json['unlock_promo_code']);
    unlockPromoCodeId = parseInt(json['unlock_promo_code_id']);
    isDeliverableAddress = parseInt(json['is_deliverable_address']);
    deliveryCharges = json['delivery_charges'] is Map<String, dynamic>
        ? DeliveryCharges.fromJson(
            json['delivery_charges'] as Map<String, dynamic>,
          )
        : null;
    surgeCharges = json['surge_charges'] is List
        ? (json['surge_charges'] as List)
              .map((v) => SurgeCharges.fromJson(v as Map<String, dynamic>))
              .toList()
        : <SurgeCharges>[];
    zoneAdditionalCharges = json['zone_additional_charges'] is List
        ? (json['zone_additional_charges'] as List)
              .map((v) => AdditionalCharges.fromJson(v as Map<String, dynamic>))
              .toList()
        : <AdditionalCharges>[];
    totalAmount = parseDouble(json['total_amount']);
    userBalance = parseDoubleOrNull(json['user_balance']);
    subTotal = parseDouble(json['sub_total']);
    savedAmount = parseDouble(json['saved_amount']);
    minimumOrderAmount = parseDouble(json['minimum_order_amount']);
    final rawCart = json['cart'];
    if (rawCart is List) {
      cart = rawCart
          .map((v) => ProductDataModel.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawAdditionalCharges = json['additional_charges'];
    if (rawAdditionalCharges is List) {
      additionalCharges = rawAdditionalCharges
          .map((v) => AdditionalCharges.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawTaxBreakdown = json['tax_breakdown'];
    if (rawTaxBreakdown is List) {
      taxBreakdown = rawTaxBreakdown
          .map((v) => TaxCharges.fromJson(v as Map<String, dynamic>))
          .toList();
    }

    currency = parseString(json['currency']);
    decimalPoint = parseInt(json['decimal_point']);

    deliveryType = parseString(json['delivery_type']);
    deliveryAvailable = parseInt(json['delivery_available']);
    pickupAvailable = parseInt(json['pickup_available']);
    pickup = json['pickup'] is Map<String, dynamic>
        ? CartPickupInfo.fromJson(json['pickup'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['cod_allowed'] = codAllowed;
    data['product_variant_id'] = productVariantId;
    data['quantity'] = quantity;
    data['distance'] = distance;
    data['time_to_deliver'] = timeToDeliver;
    data['estimated_delivery_date'] = estimatedDeliveryDate;
    data['unlock_message'] = unlockMessage;
    data['unlock_promo_code'] = unlockPromoCode;
    data['unlock_promo_code_id'] = unlockPromoCodeId;
    data['is_deliverable_address'] = isDeliverableAddress;
    data['delivery_charges'] = deliveryCharges?.toJson();
    data['surge_charges'] = surgeCharges;
    data['zone_additional_charges'] = zoneAdditionalCharges;
    data['total_amount'] = totalAmount;
    data['user_balance'] = userBalance;
    data['sub_total'] = subTotal;
    data['saved_amount'] = savedAmount;
    if (cart != null) {
      data['cart'] = cart!.map((v) => v.toJson()).toList();
    }
    if (additionalCharges != null) {
      data['additional_charges'] = additionalCharges!
          .map((v) => v.toJson())
          .toList();
    }
    if (taxBreakdown != null) {
      data['tax_breakdown'] = taxBreakdown!.map((v) => v.toJson()).toList();
    }
    data['currency'] = currency;
    data['decimal_point'] = decimalPoint;
    data['delivery_type'] = deliveryType;
    data['delivery_available'] = deliveryAvailable;
    data['pickup_available'] = pickupAvailable;
    data['pickup'] = pickup?.toJson();
    return data;
  }
}

/// Pickup store snapshot returned on the cart response — same store info as
/// the `zone` API's `store` object, plus per-cart availability/distance.
class CartPickupInfo {
  int? available;
  String? unavailableReason;
  int? branchId;
  String? branchName;
  String? address;
  double? latitude;
  double? longitude;
  String? contactNumber;
  int? preparationMinutes;
  String? preparationTime;
  bool? isOpenNow;
  double? distance;
  String? distanceUnit;

  CartPickupInfo({
    this.available,
    this.unavailableReason,
    this.branchId,
    this.branchName,
    this.address,
    this.latitude,
    this.longitude,
    this.contactNumber,
    this.preparationMinutes,
    this.preparationTime,
    this.isOpenNow,
    this.distance,
    this.distanceUnit,
  });

  CartPickupInfo.fromJson(Map<String, dynamic> json) {
    available = parseInt(json['available']);
    unavailableReason = parseString(json['unavailable_reason']);
    branchId = parseInt(json['branch_id']);
    branchName = parseString(json['branch_name']);
    address = parseString(json['address']);
    latitude = parseDoubleOrNull(json['latitude']);
    longitude = parseDoubleOrNull(json['longitude']);
    contactNumber = parseString(json['contact_number']);
    preparationMinutes = parseInt(json['preparation_minutes']);
    preparationTime = parseString(json['preparation_time']);
    isOpenNow = json['is_open_now'] is bool
        ? json['is_open_now'] as bool
        : null;
    distance = parseDoubleOrNull(json['distance']);
    distanceUnit = parseString(json['distance_unit']);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'available': available,
      'unavailable_reason': unavailableReason,
      'branch_id': branchId,
      'branch_name': branchName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contact_number': contactNumber,
      'preparation_minutes': preparationMinutes,
      'preparation_time': preparationTime,
      'is_open_now': isOpenNow,
      'distance': distance,
      'distance_unit': distanceUnit,
    };
  }
}
