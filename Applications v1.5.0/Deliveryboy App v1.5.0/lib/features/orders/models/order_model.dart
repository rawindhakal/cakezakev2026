import 'package:deliveryboy/features/orders/models/additional_charges_model.dart';
import 'package:deliveryboy/features/orders/models/address_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_boy_bonus_details_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_charges_model.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/models/storeinfo_model.dart';
import 'package:deliveryboy/features/orders/models/surge_charges_model.dart';
import 'package:deliveryboy/features/orders/models/tax_charges_model.dart';
import 'package:deliveryboy/features/orders/models/variant_attributes_model.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';

class OrderData {
  int? id;
  int? userId;
  int? deliveryBoyId;
  DeliveryBoyBonusDetails? deliveryBoyBonusDetails;
  double? deliveryBoyBonusAmount;
  int? transactionId;
  int? otp;
  String? mobile;
  String? orderNote;
  String? deliveryDate;
  String? deliverySlot;
  double? total;
  DeliveryCharges? deliveryCharges;
  double? taxAmount;
  double? taxPercentage;
  double? walletBalance;
  double? discount;
  int? promoCodeId;
  String? promoCode;
  double? promoDiscount;
  double? cashbackAmount;
  int? cashbackCredited;
  List<AdditionalCharges>? additionalCharges;
  List<SurgeCharges>? surgeCharges;
  List<TaxCharges>? taxBreakdown;
  double? finalTotal;
  double? savedAmount;
  String? currency;
  String? currencyCode;
  String? paymentMethod;
  Address? address;
  int? activeStatus;
  String? channel;
  int? addressId;
  double? remainingTotal;
  double? remainingFinal;
  double? refundAmount;
  int? orderId;
  String? deliveryBoyName;
  String? storeName;
  String? userName;
  String? userMobile;
  String? userCountryCode;
  String? orderStatus;
  String? orderStatusName;
  String? date;
  String? orderNumber;
  List<OrderItems>? items;
  StoreInfo? storeInfo;

  OrderData({
    this.id,
    this.userId,
    this.deliveryBoyId,
    this.deliveryBoyBonusDetails,
    this.deliveryBoyBonusAmount,
    this.transactionId,
    this.otp,
    this.mobile,
    this.orderNote,
    this.total,
    this.deliveryCharges,
    this.taxAmount,
    this.taxPercentage,
    this.walletBalance,
    this.discount,
    this.promoCodeId,
    this.promoCode,
    this.promoDiscount,
    this.cashbackAmount,
    this.cashbackCredited,
    this.additionalCharges,
    this.surgeCharges,
    this.taxBreakdown,
    this.finalTotal,
    this.savedAmount,
    this.currency,
    this.currencyCode,
    this.paymentMethod,
    this.address,
    this.activeStatus,
    this.channel,
    this.addressId,
    this.remainingTotal,
    this.remainingFinal,
    this.refundAmount,
    this.orderId,
    this.deliveryBoyName,
    this.storeName,
    this.userName,
    this.userMobile,
    this.userCountryCode,
    this.orderStatus,
    this.orderStatusName,
    this.date,
    this.orderNumber,
    this.items,
    this.storeInfo,
  });

  OrderData.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    userId = toSafeIntOrNull(json['user_id']);
    deliveryBoyId = toSafeIntOrNull(json['delivery_boy_id']);
    deliveryBoyBonusDetails = json['delivery_boy_bonus_details'] != null
        ? DeliveryBoyBonusDetails.fromJson(json['delivery_boy_bonus_details'])
        : null;
    deliveryBoyBonusAmount = toSafeDouble(json['delivery_boy_bonus_amount']);
    transactionId = toSafeIntOrNull(json['transaction_id']);
    otp = toSafeIntOrNull(json['otp']);
    mobile = json['mobile']?.toString();
    orderNote = json['order_note']?.toString();
    deliveryDate = json['delivery_date']?.toString();
    deliverySlot = json['delivery_slot']?.toString();
    total = toSafeDouble(json['total']);
    deliveryCharges = json['delivery_charges'] is Map<String, dynamic>
        ? DeliveryCharges.fromJson(json['delivery_charges'] as Map<String, dynamic>)
        : null;
    taxAmount = toSafeDouble(json['tax_amount']);
    taxPercentage = toSafeDouble(json['tax_percentage']);
    walletBalance = toSafeDouble(json['wallet_balance']);
    discount = toSafeDouble(json['discount']);
    promoCodeId = toSafeIntOrNull(json['promo_code_id']);
    promoCode = json['promo_code']?.toString();
    promoDiscount = toSafeDouble(json['promo_discount']);
    cashbackAmount = toSafeDouble(json['cashback_amount']);
    cashbackCredited = toSafeIntOrNull(json['cashback_credited']);
    if (json['additional_charges'] != null) {
      additionalCharges = <AdditionalCharges>[];
      json['additional_charges'].forEach((v) {
        additionalCharges!.add(AdditionalCharges.fromJson(v));
      });
    }
    if (json['surge_charges'] != null) {
      surgeCharges = <SurgeCharges>[];
      json['surge_charges'].forEach((v) {
        surgeCharges!.add(SurgeCharges.fromJson(v));
      });
    }
    if (json['tax_breakdown'] != null) {
      taxBreakdown = <TaxCharges>[];
      json['tax_breakdown'].forEach((v) {
        taxBreakdown!.add(TaxCharges.fromJson(v));
      });
    }
    finalTotal = toSafeDouble(json['final_total']);
    savedAmount = toSafeDouble(json['saved_amount']);
    currency = json['currency']?.toString();
    currencyCode = json['currency_code']?.toString();
    paymentMethod = json['payment_method']?.toString();
    address = json['address'] != null
        ? Address.fromJson(json['address'])
        : null;
    activeStatus = toSafeIntOrNull(json['active_status']);
    channel = json['channel']?.toString();
    addressId = toSafeIntOrNull(json['address_id']);
    remainingTotal = toSafeDouble(json['remaining_total']);
    remainingFinal = toSafeDouble(json['remaining_final']);
    refundAmount = toSafeDouble(json['refund_amount']);
    orderId = toSafeIntOrNull(json['order_id']);
    deliveryBoyName = json['delivery_boy_name']?.toString();
    storeName = json['branch_name']?.toString();
    userName = json['user_name']?.toString();
    userMobile = json['user_mobile']?.toString();
    userCountryCode = json['user_country_code']?.toString();
    orderStatus = json['order_status']?.toString();
    orderStatusName = json['order_status_name']?.toString();
    date = json['date']?.toString();
    orderNumber = json['order_number']?.toString();
    if (json['items'] != null) {
      items = <OrderItems>[];
      json['items'].forEach((v) {
        items!.add(OrderItems.fromJson(v));
      });
    }
    storeInfo = json['branch_info'] != null
        ? StoreInfo.fromJson(json['branch_info'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['delivery_boy_id'] = deliveryBoyId;
    if (deliveryBoyBonusDetails != null) {
      data['delivery_boy_bonus_details'] = deliveryBoyBonusDetails!.toJson();
    }
    data['delivery_boy_bonus_amount'] = deliveryBoyBonusAmount;
    data['transaction_id'] = transactionId;
    data['otp'] = otp;
    data['mobile'] = mobile;
    data['order_note'] = orderNote;
    data['total'] = total;
    data['delivery_charges'] = deliveryCharges?.toJson();
    data['tax_amount'] = taxAmount;
    data['tax_percentage'] = taxPercentage;
    data['wallet_balance'] = walletBalance;
    data['discount'] = discount;
    data['promo_code_id'] = promoCodeId;
    data['promo_code'] = promoCode;
    data['promo_discount'] = promoDiscount;
    data['cashback_amount'] = cashbackAmount;
    data['cashback_credited'] = cashbackCredited;
    if (additionalCharges != null) {
      data['additional_charges'] = additionalCharges!
          .map((v) => v.toJson())
          .toList();
    }
    if (surgeCharges != null) {
      data['surge_charges'] = surgeCharges!.map((v) => v.toJson()).toList();
    }
    if (taxBreakdown != null) {
      data['tax_breakdown'] = taxBreakdown!.map((v) => v.toJson()).toList();
    }
    data['final_total'] = finalTotal;
    data['saved_amount'] = savedAmount;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['payment_method'] = paymentMethod;
    if (address != null) {
      data['address'] = address!.toJson();
    }
    data['active_status'] = activeStatus;
    data['channel'] = channel;
    data['address_id'] = addressId;
    data['remaining_total'] = remainingTotal;
    data['remaining_final'] = remainingFinal;
    data['refund_amount'] = refundAmount;
    data['order_id'] = orderId;
    data['delivery_boy_name'] = deliveryBoyName;
    data['branch_name'] = storeName;
    data['user_name'] = userName;
    data['user_mobile'] = userMobile;
    data['user_country_code'] = userCountryCode;
    data['order_status'] = orderStatus;
    data['order_status_name'] = orderStatusName;
    data['date'] = date;
    data['order_number'] = orderNumber;
    if (items != null) {
      data['items'] = items!.map((v) => v.toJson()).toList();
    }
    if (storeInfo != null) {
      data['branch_info'] = storeInfo!.toJson();
    }
    return data;
  }
}

class OrderItems {
  int? id;
  int? userId;
  int? orderId;
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
  DeliveryCharges? deliveryCharges;
  List<AdditionalCharges>? additionalCharges;
  List<SurgeCharges>? surgeCharges;
  double? promoDiscount;
  double? walletBalance;
  double? finalTotal;
  double? refundAmount;
  int? activeStatus;
  String? cancellationReason;
  String? canceledAt;
  int? storeId;
  int? cancelableStatus;
  int? tillStatus;
  int? returnStatus;
  int? returnDays;
  int? isCredited;
  int? variantId;
  String? variantName;
  String? variantImage;
  int? productId;
  String? storeName;
  String? storeLatitude;
  String? storeLongitude;
  String? name;
  String? image;
  String? date;
  String? imageUrl;

  // Add-on module: snapshot of the chosen options as they were when
  // ordered. `addon_total` is display-only — price / discounted_price /
  // sub_total already include the addons.
  List<OrderAddon>? addons;
  double? addonTotal;

  OrderItems({
    this.id,
    this.userId,
    this.orderId,
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
    this.deliveryCharges,
    this.additionalCharges,
    this.surgeCharges,
    this.promoDiscount,
    this.walletBalance,
    this.finalTotal,
    this.refundAmount,
    this.activeStatus,
    this.cancellationReason,
    this.canceledAt,
    this.storeId,
    this.cancelableStatus,
    this.tillStatus,
    this.returnStatus,
    this.returnDays,
    this.isCredited,
    this.variantId,
    this.variantName,
    this.variantImage,
    this.productId,
    this.storeName,
    this.storeLatitude,
    this.storeLongitude,
    this.name,
    this.image,
    this.date,
    this.imageUrl,
    this.addons,
    this.addonTotal,
  });

  OrderItems.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    userId = toSafeIntOrNull(json['user_id']);
    orderId = toSafeIntOrNull(json['order_id']);
    productName = json['product_name']?.toString();
    productType = toSafeIntOrNull(json['product_type']);
    if (json['variant_attributes'] != null) {
      variantAttributes = <VariantAttributes>[];
      json['variant_attributes'].forEach((v) {
        variantAttributes!.add(VariantAttributes.fromJson(v));
      });
    }
    productVariantId = toSafeIntOrNull(json['product_variant_id']);
    deliveryBoyId = toSafeIntOrNull(json['delivery_boy_id']);
    deliveryBoyBonusDetails = json['delivery_boy_bonus_details'];
    deliveryBoyBonusAmount = toSafeDouble(json['delivery_boy_bonus_amount']);
    quantity = toSafeIntOrNull(json['quantity']);
    price = toSafeDouble(json['price']);
    discountedPrice = toSafeDouble(json['discounted_price']);
    taxAmount = toSafeDouble(json['tax_amount']);
    taxPercentage = toSafeDouble(json['tax_percentage']);
    subTotal = toSafeDouble(json['sub_total']);
    deliveryCharges = json['delivery_charges'] is Map<String, dynamic>
        ? DeliveryCharges.fromJson(json['delivery_charges'] as Map<String, dynamic>)
        : null;
    if (json['additional_charges'] != null) {
      additionalCharges = <AdditionalCharges>[];
      json['additional_charges'].forEach((v) {
        additionalCharges!.add(AdditionalCharges.fromJson(v));
      });
    }
    if (json['surge_charges'] != null) {
      surgeCharges = <SurgeCharges>[];
      json['surge_charges'].forEach((v) {
        surgeCharges!.add(SurgeCharges.fromJson(v));
      });
    }
    promoDiscount = toSafeDouble(json['promo_discount']);
    walletBalance = toSafeDouble(json['wallet_balance']);
    finalTotal = toSafeDouble(json['final_total']);
    refundAmount = toSafeDouble(json['refund_amount']);
    activeStatus = toSafeIntOrNull(json['active_status']);
    cancellationReason = json['cancellation_reason']?.toString();
    canceledAt = json['canceled_at']?.toString();
    storeId = toSafeIntOrNull(json['branch_id']);
    cancelableStatus = toSafeIntOrNull(json['cancelable_status']);
    tillStatus = toSafeIntOrNull(json['till_status']);
    returnStatus = toSafeIntOrNull(json['return_status']);
    returnDays = toSafeIntOrNull(json['return_days']);
    isCredited = toSafeIntOrNull(json['is_credited']);
    variantId = toSafeIntOrNull(json['variant_id']);
    variantName = json['variant_name']?.toString();
    variantImage = json['variant_image']?.toString();
    productId = toSafeIntOrNull(json['product_id']);
    storeName = json['branch_name']?.toString();
    storeLatitude = json['branch_latitude']?.toString();
    storeLongitude = json['branch_longitude']?.toString();
    name = json['name']?.toString();
    image = json['image']?.toString();
    date = json['date']?.toString();
    imageUrl = json['image_url']?.toString();
    // Add-on module.
    addons = parseOrderAddons(json['addons']);
    addonTotal = toSafeDoubleOrNull(json['addon_total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['order_id'] = orderId;
    data['product_name'] = productName;
    data['product_type'] = productType;
    if (variantAttributes != null) {
      data['variant_attributes'] = variantAttributes!
          .map((v) => v.toJson())
          .toList();
    }
    data['product_variant_id'] = productVariantId;
    data['delivery_boy_id'] = deliveryBoyId;
    data['delivery_boy_bonus_details'] = deliveryBoyBonusDetails;
    data['delivery_boy_bonus_amount'] = deliveryBoyBonusAmount;
    data['quantity'] = quantity;
    data['price'] = price;
    data['discounted_price'] = discountedPrice;
    data['tax_amount'] = taxAmount;
    data['tax_percentage'] = taxPercentage;
    data['sub_total'] = subTotal;
    data['delivery_charges'] = deliveryCharges?.toJson();
    if (additionalCharges != null) {
      data['additional_charges'] = additionalCharges!
          .map((v) => v.toJson())
          .toList();
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
    data['branch_id'] = storeId;
    data['cancelable_status'] = cancelableStatus;
    data['till_status'] = tillStatus;
    data['return_status'] = returnStatus;
    data['return_days'] = returnDays;
    data['is_credited'] = isCredited;
    data['variant_id'] = variantId;
    data['variant_name'] = variantName;
    data['variant_image'] = variantImage;
    data['product_id'] = productId;
    data['branch_name'] = storeName;
    data['branch_latitude'] = storeLatitude;
    data['branch_longitude'] = storeLongitude;
    data['name'] = name;
    data['image'] = image;
    data['date'] = date;
    data['image_url'] = imageUrl;
    // Add-on module.
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
    return data;
  }
}
