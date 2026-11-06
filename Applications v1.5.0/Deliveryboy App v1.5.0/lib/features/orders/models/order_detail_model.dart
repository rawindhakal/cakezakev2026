import 'package:deliveryboy/features/orders/models/additional_charges_model.dart';
import 'package:deliveryboy/features/orders/models/address_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_boy_bonus_details_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_charges_model.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/models/storeinfo_model.dart';
import 'package:deliveryboy/features/orders/models/surge_charges_model.dart';
import 'package:deliveryboy/features/orders/models/tax_charges_model.dart';
import 'package:deliveryboy/features/orders/models/timeline_model.dart';
import 'package:deliveryboy/features/orders/models/variant_attributes_model.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';

class OrderDetail {
  int? status;
  String? message;
  OrderDetailData? data;
  int? total;

  OrderDetail({this.status, this.message, this.data, this.total});

  OrderDetail.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    data = json['data'] != null ? OrderDetailData.fromJson(json['data']) : null;
    total = toSafeIntOrNull(json['total']);
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

class OrderDetailData {
  Order? order;
  List<OrderItems>? orderItems;
  List<DeliveryBoys>? deliveryBoys;
  List<Timeline>? timeline;

  OrderDetailData({
    this.order,
    this.orderItems,
    this.deliveryBoys,
    this.timeline,
  });

  OrderDetailData.fromJson(Map<String, dynamic> json) {
    order = json['order'] != null ? Order.fromJson(json['order']) : null;
    if (json['order_items'] != null) {
      orderItems = <OrderItems>[];
      json['order_items'].forEach((v) {
        orderItems!.add(OrderItems.fromJson(v));
      });
    }
    if (json['deliveryBoys'] != null) {
      deliveryBoys = <DeliveryBoys>[];
      json['deliveryBoys'].forEach((v) {
        deliveryBoys!.add(DeliveryBoys.fromJson(v));
      });
    }
    if (json['timeline'] != null) {
      timeline = <Timeline>[];
      json['timeline'].forEach((v) {
        timeline!.add(Timeline.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (order != null) {
      data['order'] = order!.toJson();
    }
    if (orderItems != null) {
      data['order_items'] = orderItems!.map((v) => v.toJson()).toList();
    }
    if (deliveryBoys != null) {
      data['deliveryBoys'] = deliveryBoys!.map((v) => v.toJson()).toList();
    }
    if (timeline != null) {
      data['timeline'] = timeline!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Order {
  int? id;
  int? userId;
  int? deliveryBoyId;
  DeliveryBoyBonusDetails? deliveryBoyBonusDetails;
  double? deliveryBoyBonusAmount;
  int? transactionId;
  int? otp;
  String? mobile;
  String? orderNote;
  // Gifting
  String? recipientName, recipientPhone, recipientRelationship, occasion;
  String? giftDeliveryDate, deliverySlot, giftDeliveryType, giftMessage, senderName, personalization;
  bool isSurprise = false;
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
  String? decimalPoint;
  String? paymentMethod;
  Address? address;
  int? activeStatus;
  String? channel;
  int? addressId;
  double? remainingTotal;
  double? remainingFinal;
  double? refundAmount;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;
  int? orderId;
  String? ordersCreatedAt;
  String? userName;
  String? userEmail;
  String? userMobile;
  String? userCountryCode;
  int? storeId;
  String? storeName;
  String? storeEmail;
  String? storeFormattedAddress;
  String? storeLatitude;
  String? storeLongitude;
  String? deliveryBoyName;
  int? orderItemId;
  String? statusName;
  StoreNameTranslation? storeNameTranslation;
  StoreNameTranslation? deliveryBoyNameTranslation;
  String? orderStatusName;
  bool? isDeliveryBoyChatVisible;
  String? orderNumber;
  StoreInfo? storeInfo;

  Order({
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
    this.decimalPoint,
    this.paymentMethod,
    this.address,
    this.activeStatus,
    this.channel,
    this.addressId,
    this.remainingTotal,
    this.remainingFinal,
    this.refundAmount,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.orderId,
    this.ordersCreatedAt,
    this.userName,
    this.userEmail,
    this.userMobile,
    this.userCountryCode,
    this.storeId,
    this.storeName,
    this.storeEmail,
    this.storeFormattedAddress,
    this.storeLatitude,
    this.storeLongitude,
    this.deliveryBoyName,
    this.orderItemId,
    this.statusName,
    this.storeNameTranslation,
    this.deliveryBoyNameTranslation,
    this.orderStatusName,
    this.isDeliveryBoyChatVisible,
    this.orderNumber,
    this.storeInfo,
  });

  Order.fromJson(Map<String, dynamic> json) {
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
    recipientName = json['recipient_name']?.toString();
    recipientPhone = json['recipient_phone']?.toString();
    recipientRelationship = json['recipient_relationship']?.toString();
    occasion = json['occasion']?.toString();
    giftDeliveryDate = json['delivery_date']?.toString();
    deliverySlot = json['delivery_slot']?.toString();
    giftDeliveryType = json['gift_delivery_type']?.toString();
    giftMessage = json['gift_message']?.toString();
    senderName = json['sender_name']?.toString();
    personalization = json['personalization']?.toString();
    isSurprise = '${json['is_surprise']}' == '1';
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
    decimalPoint = json['decimal_point']?.toString();
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
    createdAt = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    deletedAt = json['deleted_at']?.toString();
    orderId = toSafeIntOrNull(json['order_id']);
    ordersCreatedAt = json['orders_created_at']?.toString();
    userName = json['user_name']?.toString();
    userEmail = json['user_email']?.toString();
    userMobile = json['user_mobile']?.toString();
    userCountryCode = json['user_country_code']?.toString();
    storeId = toSafeIntOrNull(json['branch_id']);
    storeName = json['branch_name']?.toString();
    storeEmail = json['branch_email']?.toString();
    storeFormattedAddress = json['branch_formatted_address']?.toString();
    storeLatitude = json['branch_latitude']?.toString();
    storeLongitude = json['branch_longitude']?.toString();
    deliveryBoyName = json['delivery_boy_name']?.toString();
    orderItemId = toSafeIntOrNull(json['order_item_id']);
    statusName = json['status_name']?.toString();
    storeNameTranslation = json['branch_name_translation'] != null
        ? StoreNameTranslation.fromJson(json['branch_name_translation'])
        : null;
    deliveryBoyNameTranslation = json['delivery_boy_name_translation'] != null
        ? StoreNameTranslation.fromJson(json['delivery_boy_name_translation'])
        : null;
    orderStatusName = json['order_status_name']?.toString();
    isDeliveryBoyChatVisible = toSafeBool(
      json['is_delivery_boy_chat_visible'],
      false,
    );
    orderNumber = json['order_number']?.toString();
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
    data['decimal_point'] = decimalPoint;
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
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    data['order_id'] = orderId;
    data['orders_created_at'] = ordersCreatedAt;
    data['user_name'] = userName;
    data['user_email'] = userEmail;
    data['user_mobile'] = userMobile;
    data['user_country_code'] = userCountryCode;
    data['branch_id'] = storeId;
    data['branch_name'] = storeName;
    data['branch_email'] = storeEmail;
    data['branch_formatted_address'] = storeFormattedAddress;
    data['branch_latitude'] = storeLatitude;
    data['branch_longitude'] = storeLongitude;
    data['delivery_boy_name'] = deliveryBoyName;
    data['order_item_id'] = orderItemId;
    data['status_name'] = statusName;
    if (storeNameTranslation != null) {
      data['branch_name_translation'] = storeNameTranslation!.toJson();
    }
    if (deliveryBoyNameTranslation != null) {
      data['delivery_boy_name_translation'] = deliveryBoyNameTranslation!
          .toJson();
    }
    data['order_status_name'] = orderStatusName;
    data['is_delivery_boy_chat_visible'] = isDeliveryBoyChatVisible;
    data['order_number'] = orderNumber;
    if (storeInfo != null) {
      data['branch_info'] = storeInfo!.toJson();
    }
    return data;
  }
}

class StoreNameTranslation {
  String? lang;
  String? name;

  StoreNameTranslation({this.lang, this.name});

  StoreNameTranslation.fromJson(Map<String, dynamic> json) {
    lang = json['lang']?.toString();
    name = json['name']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['lang'] = lang;
    data['name'] = name;
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
  List<DeliveryBoyBonusDetails>? deliveryBoyBonusDetails;
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
  String? status;
  int? activeStatus;
  String? cancellationReason;
  String? canceledAt;
  int? storeId;
  int? cancelableStatus;
  int? tillStatus;
  int? returnStatus;
  int? returnDays;
  int? isCredited;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;
  String? mobile;
  String? orderTotal;
  double? orderDeliveryCharge;
  double? discount;
  String? promoCode;
  double? orderPromoDiscount;
  double? orderWalletBalance;
  double? orderFinalTotal;
  String? paymentMethod;
  String? userName;
  String? orderStatus;
  String? storeName;
  int? productId;
  String? image;
  String? statusName;
  int? isProductReturned;
  StoreNameTranslation? storeNameTranslation;
  String? orderStatusName;

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
    this.status,
    this.activeStatus,
    this.cancellationReason,
    this.canceledAt,
    this.storeId,
    this.cancelableStatus,
    this.tillStatus,
    this.returnStatus,
    this.returnDays,
    this.isCredited,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.mobile,
    this.orderTotal,
    this.orderDeliveryCharge,
    this.discount,
    this.promoCode,
    this.orderPromoDiscount,
    this.orderWalletBalance,
    this.orderFinalTotal,
    this.paymentMethod,
    this.userName,
    this.orderStatus,
    this.storeName,
    this.productId,
    this.image,
    this.statusName,
    this.isProductReturned,
    this.storeNameTranslation,
    this.orderStatusName,
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
    if (json['delivery_boy_bonus_details'] != null) {
      deliveryBoyBonusDetails = <DeliveryBoyBonusDetails>[];
      json['delivery_boy_bonus_details'].forEach((v) {
        deliveryBoyBonusDetails!.add(DeliveryBoyBonusDetails.fromJson(v));
      });
    }
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
    status = json['status']?.toString();
    activeStatus = toSafeIntOrNull(json['active_status']);
    cancellationReason = json['cancellation_reason']?.toString();
    canceledAt = json['canceled_at']?.toString();
    storeId = toSafeIntOrNull(json['branch_id']);
    cancelableStatus = toSafeIntOrNull(json['cancelable_status']);
    tillStatus = toSafeIntOrNull(json['till_status']);
    returnStatus = toSafeIntOrNull(json['return_status']);
    returnDays = toSafeIntOrNull(json['return_days']);
    isCredited = toSafeIntOrNull(json['is_credited']);
    createdAt = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    deletedAt = json['deleted_at']?.toString();
    mobile = json['mobile']?.toString();
    orderTotal = json['order_total']?.toString();
    orderDeliveryCharge = toSafeDouble(json['order_delivery_charge']);
    discount = toSafeDouble(json['discount']);
    promoCode = json['promo_code']?.toString();
    orderPromoDiscount = toSafeDouble(json['order_promo_discount']);
    orderWalletBalance = toSafeDouble(json['order_wallet_balance']);
    orderFinalTotal = toSafeDouble(json['order_final_total']);
    paymentMethod = json['payment_method']?.toString();
    userName = json['user_name']?.toString();
    orderStatus = json['order_status']?.toString();
    storeName = json['branch_name']?.toString();
    productId = toSafeIntOrNull(json['product_id']);
    image = json['image']?.toString();
    statusName = json['status_name']?.toString();
    isProductReturned = toSafeIntOrNull(json['is_product_returned']);
    storeNameTranslation = json['branch_name_translation'] != null
        ? StoreNameTranslation.fromJson(json['branch_name_translation'])
        : null;
    orderStatusName = json['order_status_name']?.toString();
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
    if (deliveryBoyBonusDetails != null) {
      data['delivery_boy_bonus_details'] = deliveryBoyBonusDetails!
          .map((v) => v.toJson())
          .toList();
    }
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
    data['status'] = status;
    data['active_status'] = activeStatus;
    data['cancellation_reason'] = cancellationReason;
    data['canceled_at'] = canceledAt;
    data['branch_id'] = storeId;
    data['cancelable_status'] = cancelableStatus;
    data['till_status'] = tillStatus;
    data['return_status'] = returnStatus;
    data['return_days'] = returnDays;
    data['is_credited'] = isCredited;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    data['mobile'] = mobile;
    data['order_total'] = orderTotal;
    data['order_delivery_charge'] = orderDeliveryCharge;
    data['discount'] = discount;
    data['promo_code'] = promoCode;
    data['order_promo_discount'] = orderPromoDiscount;
    data['order_wallet_balance'] = orderWalletBalance;
    data['order_final_total'] = orderFinalTotal;
    data['payment_method'] = paymentMethod;
    data['user_name'] = userName;
    data['order_status'] = orderStatus;
    data['branch_name'] = storeName;
    data['product_id'] = productId;
    data['image'] = image;
    data['status_name'] = statusName;
    data['is_product_returned'] = isProductReturned;
    if (storeNameTranslation != null) {
      data['branch_name_translation'] = storeNameTranslation!.toJson();
    }
    data['order_status_name'] = orderStatusName;
    // Add-on module.
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
    return data;
  }
}

class DeliveryBoys {
  int? id;
  Name? name;
  int? pendingOrderCount;
  String? drivingLicenseUrl;
  String? nationalIdentityCardUrl;

  DeliveryBoys({
    this.id,
    this.name,
    this.pendingOrderCount,
    this.drivingLicenseUrl,
    this.nationalIdentityCardUrl,
  });

  DeliveryBoys.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    name = json['name'] != null ? Name.fromJson(json['name']) : null;
    pendingOrderCount = toSafeIntOrNull(json['pending_order_count']);
    drivingLicenseUrl = json['driving_license_url']?.toString();
    nationalIdentityCardUrl = json['national_identity_card_url']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    if (name != null) {
      data['name'] = name!.toJson();
    }
    data['pending_order_count'] = pendingOrderCount;
    data['driving_license_url'] = drivingLicenseUrl;
    data['national_identity_card_url'] = nationalIdentityCardUrl;
    return data;
  }
}

class Name {
  String? en;
  String? ur;

  Name({this.en, this.ur});

  Name.fromJson(Map<String, dynamic> json) {
    en = json['en']?.toString();
    ur = json['ur']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['en'] = en;
    data['ur'] = ur;
    return data;
  }
}
