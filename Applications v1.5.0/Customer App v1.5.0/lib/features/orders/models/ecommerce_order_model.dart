import 'package:customer/commons/models/additional_charges_model.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/commons/models/delivery_charges_model.dart';
import 'package:customer/commons/models/surge_charges_model.dart';
import 'package:customer/commons/models/tax_charges_model.dart';
import 'package:customer/features/orders/models/order_address_model.dart';
import 'package:customer/features/orders/models/order_model.dart'
    show ItemRating, OrderPickupStore, VariantAttributes;
import 'package:customer/utils/json_parsers.dart';

class EcommerceOrderModel {
  int? status;
  String? message;
  List<EcommerceOrderDataModel>? data;
  int? total;

  EcommerceOrderModel({this.status, this.message, this.data, this.total});

  EcommerceOrderModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map(
            (v) => EcommerceOrderDataModel.fromJson(v as Map<String, dynamic>),
          )
          .toList();
    }
    total = parseInt(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['total'] = total;
    return data;
  }
}

class EcommerceOrderDataModel {
  int? id;
  int? userId;
  int? orderId;
  String? orderNumber;
  String? productName;
  int? productType;
  List<VariantAttributes>? variantAttributes;
  int? productVariantId;
  int? deliveryBoyId;
  DeliveryBoyBonusDetails? deliveryBoyBonusDetails;
  double? deliveryBoyBonusAmount;
  int? quantity;
  double? price;
  double? discountedPrice;
  double? taxAmount;
  double? taxPercentage;
  double? subTotal;
  DeliveryCharges? deliveryCharge;
  List<AdditionalCharges>? additionalCharges;
  List<TaxCharges>? taxBreakdown;
  List<SurgeCharges>? surgeCharges;
  double? promoDiscount;
  double? walletBalance;
  double? finalTotal;
  double? refundAmount;
  int? activeStatus;
  String? cancellationReason;
  String? canceledAt;
  int? branchId;
  int? isCredited;
  String? channel;
  String? paymentMethod;
  String? currency;
  String? currencyCode;
  int? decimalPoint;
  int? variantId;
  String? name;
  int? productId;
  String? image;
  String? returnRejectReason;
  String? returnReason;
  String? branchName;
  String? deliveryBoyName;
  String? deliveryBoyMobile;
  bool? isDeliveryBoyChatVisible;
  int? returnRequested;
  String? orderStatusName;
  bool? productRating;
  String? date;
  List<Timeline>? timeline;
  List<OtherItems>? otherItems;
  List<ItemRating>? itemRating;
  bool? isCancellable;
  bool? isReturnable;
  double? savedAmount;
  double? cashbackAmount;
  int? cashbackCredited;
  OrderAddressModel? address;
  int? returnDays;
  int? otp;
  String? courierAgency;
  String? trackingId;
  String? trackingUrl;
  String? returnCourierAgency;
  String? returnTrackingId;
  String? returnTrackingUrl;
  String? orderItemStatus;
  String? prescriptionUrl;

  /// 'delivery' | 'pickup'. `pickupStore` is null for delivery orders.
  String? deliveryType;
  OrderPickupStore? pickupStore;
  String? estimatedDeliveryDate;

  // Add-on module: snapshot of the chosen options as they were when
  // ordered. `addon_total` is display-only — price / discounted_price /
  // sub_total already include the addons.
  List<CartAddon>? addons;
  double? addonTotal;

  /// Buyer tax fields — same contract as `OrderData.buyerTaxNumber` /
  /// `buyerTaxLabel` / `buyerBusinessName`: number frozen at placement, label
  /// is the wording at order time (print it, not the current
  /// `country_setting` label), all `null` on a consumer order.
  String? buyerTaxNumber;
  String? buyerTaxLabel;
  String? buyerBusinessName;

  EcommerceOrderDataModel({
    this.id,
    this.userId,
    this.orderId,
    this.orderNumber,
    this.productName,
    this.productType,
    this.variantAttributes,
    this.productVariantId,
    this.deliveryBoyId,
    this.deliveryBoyBonusDetails,
    this.deliveryBoyBonusAmount,
    this.quantity,
    this.price,
    this.discountedPrice,
    this.taxAmount,
    this.taxPercentage,
    this.subTotal,
    this.deliveryCharge,
    this.additionalCharges,
    this.taxBreakdown,
    this.surgeCharges,
    this.promoDiscount,
    this.walletBalance,
    this.finalTotal,
    this.refundAmount,
    this.activeStatus,
    this.cancellationReason,
    this.canceledAt,
    this.branchId,
    this.isCredited,
    this.channel,
    this.paymentMethod,
    this.currency,
    this.currencyCode,
    this.decimalPoint,
    this.variantId,
    this.name,
    this.productId,
    this.image,
    this.returnRejectReason,
    this.returnReason,
    this.branchName,
    this.deliveryBoyName,
    this.deliveryBoyMobile,
    this.isDeliveryBoyChatVisible,
    this.returnRequested,
    this.orderStatusName,
    this.productRating,
    this.date,
    this.timeline,
    this.otherItems,
    this.itemRating,
    this.isCancellable,
    this.isReturnable,
    this.savedAmount,
    this.cashbackAmount,
    this.cashbackCredited,
    this.address,
    this.returnDays,
    this.otp,
    this.courierAgency,
    this.trackingId,
    this.trackingUrl,
    this.returnCourierAgency,
    this.returnTrackingId,
    this.returnTrackingUrl,
    this.orderItemStatus,
    this.prescriptionUrl,
    this.deliveryType,
    this.pickupStore,
    this.estimatedDeliveryDate,
    this.addons,
    this.addonTotal,
    this.buyerTaxNumber,
    this.buyerTaxLabel,
    this.buyerBusinessName,
  });

  EcommerceOrderDataModel.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    userId = parseInt(json['user_id']);
    orderId = parseInt(json['order_id']);
    orderNumber = parseString(json['order_number']);
    productName = parseString(json['product_name']);
    productType = parseInt(json['product_type']);
    final rawVariantAttributes = json['variant_attributes'];
    if (rawVariantAttributes is List) {
      variantAttributes = rawVariantAttributes
          .map((v) => VariantAttributes.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    productVariantId = parseInt(json['product_variant_id']);
    deliveryBoyId = parseInt(json['delivery_boy_id']);
    deliveryBoyBonusDetails =
        json['delivery_boy_bonus_details'] is Map<String, dynamic>
        ? DeliveryBoyBonusDetails.fromJson(
            json['delivery_boy_bonus_details'] as Map<String, dynamic>,
          )
        : null;
    deliveryBoyBonusAmount = parseDouble(json['delivery_boy_bonus_amount']);
    quantity = parseInt(json['quantity']);
    price = parseDouble(json['price']);
    discountedPrice = parseDouble(json['discounted_price']);
    taxAmount = parseDouble(json['tax_amount']);
    taxPercentage = parseDouble(json['tax_percentage']);
    subTotal = parseDouble(json['sub_total']);
    deliveryCharge = json['delivery_charges'] is Map<String, dynamic>
        ? DeliveryCharges.fromJson(
            json['delivery_charges'] as Map<String, dynamic>,
          )
        : null;
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
    final rawSurgeCharges = json['surge_charges'];
    if (rawSurgeCharges is List) {
      surgeCharges = rawSurgeCharges
          .map((v) => SurgeCharges.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    promoDiscount = parseDouble(json['promo_discount']);
    walletBalance = parseDouble(json['wallet_balance']);
    finalTotal = parseDouble(json['final_total']);
    refundAmount = parseDouble(json['refund_amount']);
    activeStatus = parseInt(json['active_status']);
    cancellationReason = parseString(json['cancellation_reason']);
    canceledAt = parseString(json['canceled_at']);
    branchId = parseInt(json['branch_id']);
    isCredited = parseInt(json['is_credited']);
    channel = parseString(json['channel']);
    paymentMethod = parseString(json['payment_method']);
    currency = parseString(json['currency']);
    currencyCode = parseString(json['currency_code']);
    decimalPoint = parseInt(json['decimal_point']);
    variantId = parseInt(json['variant_id']);
    name = parseString(json['name']);
    productId = parseInt(json['product_id']);
    image = parseString(json['image']);
    returnRejectReason = parseString(json['return_reject_reason']);
    returnReason = parseString(json['return_reason']);
    branchName = parseString(json['branch_name']);
    deliveryBoyName = parseString(json['delivery_boy_name']);
    deliveryBoyMobile = parseString(json['delivery_boy_mobile']);
    isDeliveryBoyChatVisible =
        parseBool(json['is_delivery_boy_chat_visible']) ?? false;
    returnRequested = parseInt(json['return_requested']);
    orderStatusName = parseString(json['order_status_name']);
    productRating = parseBool(json['product_rating']);
    date = parseString(json['date']);
    final rawTimeline = json['timeline'];
    if (rawTimeline is List) {
      timeline = rawTimeline
          .map((v) => Timeline.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawOtherItems = json['other_items'];
    if (rawOtherItems is List) {
      otherItems = rawOtherItems
          .map((v) => OtherItems.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawItemRating = json['item_rating'];
    if (rawItemRating is List) {
      itemRating = rawItemRating
          .map((v) => ItemRating.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    isCancellable = parseBool(json['is_cancellable']) ?? false;
    isReturnable = parseBool(json['is_returnable']) ?? false;
    savedAmount = parseDouble(json['saved_amount']);
    cashbackAmount = parseDouble(json['cashback_amount']);
    cashbackCredited = parseInt(json['cashback_credited']);
    address = json['address'] is Map<String, dynamic>
        ? OrderAddressModel.fromJson(json['address'] as Map<String, dynamic>)
        : null;
    buyerTaxNumber = parseString(json['buyer_tax_number']);
    buyerTaxLabel = parseString(json['buyer_tax_label']);
    buyerBusinessName = parseString(json['buyer_business_name']);
    returnDays = parseInt(json['return_days']);
    otp = parseInt(json['otp']);
    courierAgency = parseString(json['courier_agency']) ?? "";
    trackingId = parseString(json['tracking_id']) ?? "";
    trackingUrl = parseString(json['tracking_url']) ?? "";
    returnCourierAgency = parseString(json['return_courier_agency']) ?? "";
    returnTrackingId = parseString(json['return_tracking_id']) ?? "";
    returnTrackingUrl = parseString(json['return_tracking_url']) ?? "";
    orderItemStatus = parseString(json['order_item_status']) ?? "";
    prescriptionUrl = parseString(json['prescription_url']) ?? "";
    deliveryType = parseString(json['delivery_type']);
    // Store → Branch rename (1.5.0); `pickup_store` kept as a read fallback
    // since the rename checklist doesn't list this object key.
    final rawPickup = json['pickup_branch'] ?? json['pickup_store'];
    pickupStore = rawPickup is Map<String, dynamic>
        ? OrderPickupStore.fromJson(rawPickup)
        : null;
    estimatedDeliveryDate = parseString(json['estimated_delivery_date']);
    // Add-on module.
    addons = parseCartAddons(json['addons']);
    addonTotal = parseDouble(json['addon_total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['order_id'] = orderId;
    data['order_number'] = orderNumber;
    data['product_name'] = productName;
    data['product_type'] = productType;
    if (variantAttributes != null) {
      data['variant_attributes'] = variantAttributes!
          .map((v) => v.toJson())
          .toList();
    }
    data['product_variant_id'] = productVariantId;
    data['delivery_boy_id'] = deliveryBoyId;
    if (deliveryBoyBonusDetails != null) {
      data['delivery_boy_bonus_details'] = deliveryBoyBonusDetails!.toJson();
    }
    data['delivery_boy_bonus_amount'] = deliveryBoyBonusAmount;
    data['quantity'] = quantity;
    data['price'] = price;
    data['discounted_price'] = discountedPrice;
    data['tax_amount'] = taxAmount;
    data['tax_percentage'] = taxPercentage;
    data['sub_total'] = subTotal;
    data['delivery_charges'] = deliveryCharge?.toJson();
    if (additionalCharges != null) {
      data['additional_charges'] = additionalCharges!
          .map((v) => v.toJson())
          .toList();
    }
    if (taxBreakdown != null) {
      data['tax_breakdown'] = taxBreakdown!.map((v) => v.toJson()).toList();
    }
    if (surgeCharges != null) {
      data['surge_charges'] = surgeCharges!.map((v) => v.toJson()).toList();
    }
    data['promo_discount'] = promoDiscount;
    data['wallet_balance'] = walletBalance;
    data['final_total'] = finalTotal;
    data['refund_amount'] = refundAmount;
    data['active_status'] = activeStatus;
    data['cancellation_reason'] = cancellationReason;
    data['canceled_at'] = canceledAt;
    data['branch_id'] = branchId;
    data['is_credited'] = isCredited;
    data['channel'] = channel;
    data['payment_method'] = paymentMethod;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['decimal_point'] = decimalPoint;
    data['variant_id'] = variantId;
    data['name'] = name;
    data['product_id'] = productId;
    data['image'] = image;
    data['return_reject_reason'] = returnRejectReason;
    data['return_reason'] = returnReason;
    data['branch_name'] = branchName;
    data['delivery_boy_name'] = deliveryBoyName;
    data['delivery_boy_mobile'] = deliveryBoyMobile;
    data['is_delivery_boy_chat_visible'] = isDeliveryBoyChatVisible;
    data['return_requested'] = returnRequested;
    data['order_status_name'] = orderStatusName;
    data['product_rating'] = productRating;
    data['date'] = date;
    if (timeline != null) {
      data['timeline'] = timeline!.map((v) => v.toJson()).toList();
    }
    if (otherItems != null) {
      data['other_items'] = otherItems!.map((v) => v.toJson()).toList();
    }
    if (itemRating != null) {
      data['item_rating'] = itemRating!.map((v) => v.toJson()).toList();
    }
    data['is_cancellable'] = isCancellable;
    data['is_returnable'] = isReturnable;
    data['saved_amount'] = savedAmount;
    data['cashback_amount'] = cashbackAmount;
    data['cashback_credited'] = cashbackCredited;
    if (address != null) data['address'] = address!.toJson();
    data['return_days'] = returnDays;
    data['otp'] = otp;
    data['courier_agency'] = courierAgency;
    data['tracking_id'] = trackingId;
    data['tracking_url'] = trackingUrl;
    data['return_courier_agency'] = returnCourierAgency;
    data['return_tracking_id'] = returnTrackingId;
    data['return_tracking_url'] = returnTrackingUrl;
    data['order_item_status'] = orderItemStatus;
    data['prescription_url'] = prescriptionUrl;
    data['delivery_type'] = deliveryType;
    data['pickup_branch'] = pickupStore?.toJson();
    data['estimated_delivery_date'] = estimatedDeliveryDate;
    // Add-on module.
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
    return data;
  }
}

class DeliveryBoyBonusDetails {
  double? finalTotal;
  int? bonusType;
  String? bonusTypeName;
  double? bonusAmount;

  DeliveryBoyBonusDetails({
    this.finalTotal,
    this.bonusType,
    this.bonusTypeName,
    this.bonusAmount,
  });

  DeliveryBoyBonusDetails.fromJson(Map<String, dynamic> json) {
    finalTotal = parseDouble(json['final_total']);
    bonusType = parseInt(json['bonus_type']);
    bonusTypeName = parseString(json['bonus_type_name']);
    bonusAmount = parseDouble(json['bonus_amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['final_total'] = finalTotal;
    data['bonus_type'] = bonusType;
    data['bonus_type_name'] = bonusTypeName;
    data['bonus_amount'] = bonusAmount;
    return data;
  }
}

class Timeline {
  int? status;
  String? statusName;
  String? datetime;
  bool? isDone;
  bool? isCurrent;

  Timeline({
    this.status,
    this.statusName,
    this.datetime,
    this.isDone,
    this.isCurrent,
  });

  Timeline.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    statusName = parseString(json['status_name']);
    datetime = parseString(json['datetime']);
    isDone = parseBool(json['is_done']);
    isCurrent = parseBool(json['is_current']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['status_name'] = statusName;
    data['datetime'] = datetime;
    data['is_done'] = isDone;
    data['is_current'] = isCurrent;
    return data;
  }
}

class OtherItems {
  int? orderItemId;
  String? productName;
  int? productType;
  int? quantity;
  double? finalTotal;
  String? image;
  int? status;
  String? statusName;

  OtherItems({
    this.orderItemId,
    this.productName,
    this.productType,
    this.quantity,
    this.finalTotal,
    this.image,
    this.status,
    this.statusName,
  });

  OtherItems.fromJson(Map<String, dynamic> json) {
    orderItemId = parseInt(json['order_item_id']);
    productName = parseString(json['product_name']);
    productType = parseInt(json['product_type']);
    quantity = parseInt(json['quantity']);
    finalTotal = parseDouble(json['final_total']);
    image = parseString(json['image']);
    status = parseInt(json['status']);
    statusName = parseString(json['status_name']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['order_item_id'] = orderItemId;
    data['product_name'] = productName;
    data['product_type'] = productType;
    data['quantity'] = quantity;
    data['final_total'] = finalTotal;
    data['image'] = image;
    data['status'] = status;
    data['status_name'] = statusName;
    return data;
  }
}
