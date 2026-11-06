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

class EcommerceOrderDataModel {
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
  List<TaxCharges>? taxBreakdown;
  double? promoDiscount;
  double? walletBalance;
  double? finalTotal;
  double? savedAmount;
  double? refundAmount;
  int? activeStatus;
  int? otp;
  String? cancellationReason;
  String? canceledAt;
  int? storeId;
  int? isCredited;
  String? channel;
  String? paymentMethod;
  String? orderAddress;
  Address? addressInfo;
  String? orderMobile;
  String? orderNote;
  String? currency;
  String? currencyCode;
  String? decimalPoint;
  String? orderCreatedAt;
  String? latitude;
  String? longitude;
  int? variantId;
  String? name;
  int? productId;
  String? image;
  int? returnStatus;
  int? returnDays;
  int? cancelableStatus;
  int? tillStatus;
  String? storeName;
  String? deliveryBoyName;
  String? deliveryBoyMobile;
  int? returnRequested;
  String? orderStatusName;
  bool? productRating;
  String? date;
  List<Timeline>? timeline;
  List<OtherItems>? otherItems;
  List<ItemRating>? itemRating;
  StoreInfo? storeInfo;
  bool? isDeliveryBoyChatVisible;
  String? orderItemStatus;
  String? orderNumber;

  // Add-on module: snapshot of the chosen options as they were when
  // ordered. `addon_total` is display-only — price / discounted_price /
  // sub_total already include the addons.
  List<OrderAddon>? addons;
  double? addonTotal;

  EcommerceOrderDataModel({
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
    this.taxBreakdown,
    this.promoDiscount,
    this.walletBalance,
    this.finalTotal,
    this.savedAmount,
    this.refundAmount,
    this.activeStatus,
    this.otp,
    this.cancellationReason,
    this.canceledAt,
    this.storeId,
    this.isCredited,
    this.channel,
    this.paymentMethod,
    this.orderAddress,
    this.addressInfo,
    this.orderMobile,
    this.orderNote,
    this.currency,
    this.currencyCode,
    this.decimalPoint,
    this.orderCreatedAt,
    this.latitude,
    this.longitude,
    this.variantId,
    this.name,
    this.productId,
    this.image,
    this.returnStatus,
    this.returnDays,
    this.cancelableStatus,
    this.tillStatus,
    this.storeName,
    this.deliveryBoyName,
    this.deliveryBoyMobile,
    this.returnRequested,
    this.orderStatusName,
    this.productRating,
    this.date,
    this.timeline,
    this.otherItems,
    this.itemRating,
    this.storeInfo,
    this.isDeliveryBoyChatVisible,
    this.orderItemStatus,
    this.orderNumber,
    this.addons,
    this.addonTotal,
  });

  EcommerceOrderDataModel.fromJson(Map<String, dynamic> json) {
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
    deliveryBoyBonusDetails = json['delivery_boy_bonus_details'] != null
        ? DeliveryBoyBonusDetails.fromJson(json['delivery_boy_bonus_details'])
        : null;
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
    if (json['tax_breakdown'] != null) {
      taxBreakdown = <TaxCharges>[];
      json['tax_breakdown'].forEach((v) {
        taxBreakdown!.add(TaxCharges.fromJson(v));
      });
    }
    promoDiscount = toSafeDouble(json['promo_discount']);
    walletBalance = toSafeDouble(json['wallet_balance']);
    finalTotal = toSafeDouble(json['final_total']);
    savedAmount = toSafeDouble(json['saved_amount']);
    refundAmount = toSafeDouble(json['refund_amount']);
    activeStatus = toSafeIntOrNull(json['active_status']);
    otp = toSafeIntOrNull(json['otp']);
    cancellationReason = json['cancellation_reason']?.toString();
    canceledAt = json['canceled_at']?.toString();
    storeId = toSafeIntOrNull(json['branch_id']);
    isCredited = toSafeIntOrNull(json['is_credited']);
    channel = json['channel']?.toString();
    paymentMethod = json['payment_method']?.toString();
    orderAddress = json['order_address']?.toString();
    addressInfo = json['address'] is Map<String, dynamic>
        ? Address.fromJson(json['address'])
        : null;
    orderMobile = json['order_mobile']?.toString();
    orderNote = json['order_note']?.toString();
    currency = json['currency']?.toString();
    currencyCode = json['currency_code']?.toString();
    decimalPoint = json['decimal_point']?.toString();
    orderCreatedAt = json['order_created_at']?.toString();
    latitude = json['latitude']?.toString();
    longitude = json['longitude']?.toString();
    variantId = toSafeIntOrNull(json['variant_id']);
    name = json['name']?.toString();
    productId = toSafeIntOrNull(json['product_id']);
    image = json['image']?.toString();
    returnStatus = toSafeIntOrNull(json['return_status']);
    returnDays = toSafeIntOrNull(json['return_days']);
    cancelableStatus = toSafeIntOrNull(json['cancelable_status']);
    tillStatus = toSafeIntOrNull(json['till_status']);
    storeName = json['branch_name']?.toString();
    deliveryBoyName = json['delivery_boy_name']?.toString();
    deliveryBoyMobile = json['delivery_boy_mobile']?.toString();
    returnRequested = toSafeIntOrNull(json['return_requested']);
    orderStatusName = json['order_status_name']?.toString();
    productRating = toSafeBoolOrNull(json['product_rating']);
    date = json['date']?.toString();
    if (json['timeline'] != null) {
      timeline = <Timeline>[];
      json['timeline'].forEach((v) {
        timeline!.add(Timeline.fromJson(v));
      });
    }
    if (json['other_items'] != null) {
      otherItems = <OtherItems>[];
      json['other_items'].forEach((v) {
        otherItems!.add(OtherItems.fromJson(v));
      });
    }
    if (json['item_rating'] != null) {
      itemRating = <ItemRating>[];
      json['item_rating'].forEach((v) {
        itemRating!.add(ItemRating.fromJson(v));
      });
    }
    storeInfo = json['branch_info'] != null
        ? StoreInfo.fromJson(json['branch_info'])
        : null;
    isDeliveryBoyChatVisible = toSafeBool(json['is_delivery_boy_chat_visible']);
    orderItemStatus = json['order_item_status']?.toString() ?? "";
    orderNumber = json['order_number']?.toString();
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
      data['delivery_boy_bonus_details'] = deliveryBoyBonusDetails!.toJson();
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
    if (taxBreakdown != null) {
      data['tax_breakdown'] = taxBreakdown!.map((v) => v.toJson()).toList();
    }
    data['promo_discount'] = promoDiscount;
    data['wallet_balance'] = walletBalance;
    data['final_total'] = finalTotal;
    data['saved_amount'] = savedAmount;
    data['refund_amount'] = refundAmount;
    data['active_status'] = activeStatus;
    data['otp'] = otp;
    data['cancellation_reason'] = cancellationReason;
    data['canceled_at'] = canceledAt;
    data['branch_id'] = storeId;
    data['is_credited'] = isCredited;
    data['channel'] = channel;
    data['payment_method'] = paymentMethod;
    data['order_address'] = orderAddress;
    if (addressInfo != null) data['address'] = addressInfo!.toJson();
    data['order_mobile'] = orderMobile;
    data['order_note'] = orderNote;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['decimal_point'] = decimalPoint;
    data['order_created_at'] = orderCreatedAt;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['variant_id'] = variantId;
    data['name'] = name;
    data['product_id'] = productId;
    data['image'] = image;
    data['return_status'] = returnStatus;
    data['return_days'] = returnDays;
    data['cancelable_status'] = cancelableStatus;
    data['till_status'] = tillStatus;
    data['branch_name'] = storeName;
    data['delivery_boy_name'] = deliveryBoyName;
    data['delivery_boy_mobile'] = deliveryBoyMobile;
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
    if (storeInfo != null) {
      data['branch_info'] = storeInfo!.toJson();
    }
    data['is_delivery_boy_chat_visible'] = isDeliveryBoyChatVisible;
    data['order_item_status'] = orderItemStatus;
    data['order_number'] = orderNumber;
    // Add-on module.
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
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
    orderItemId = toSafeIntOrNull(json['order_item_id']);
    productName = json['product_name']?.toString();
    productType = toSafeIntOrNull(json['product_type']);
    quantity = toSafeIntOrNull(json['quantity']);
    finalTotal = toSafeDouble(json['final_total']);
    image = json['image']?.toString();
    status = toSafeIntOrNull(json['status']);
    statusName = json['status_name']?.toString();
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

class ItemRating {
  String? id;
  String? productId;
  String? userId;
  String? rate;
  String? review;
  String? status;
  String? updatedAt;
  ItemRatingUser? user;
  List<ItemRatingImages>? images;

  ItemRating({
    this.id,
    this.productId,
    this.userId,
    this.rate,
    this.review,
    this.status,
    this.updatedAt,
    this.user,
    this.images,
  });

  ItemRating.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    productId = json['product_id']?.toString();
    userId = json['user_id']?.toString();
    rate = json['rate']?.toString();
    review = json['review']?.toString();
    status = json['status']?.toString();
    updatedAt = json['updated_at']?.toString();
    user = json['user'] != null ? ItemRatingUser.fromJson(json['user']) : null;
    if (json['images'] != null) {
      images = <ItemRatingImages>[];
      json['images'].forEach((v) {
        images!.add(ItemRatingImages.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product_id'] = productId;
    data['user_id'] = userId;
    data['rate'] = rate;
    data['review'] = review;
    data['status'] = status;
    data['updated_at'] = updatedAt;
    if (user != null) data['user'] = user!.toJson();
    if (images != null) {
      data['images'] = images!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ItemRatingUser {
  String? id;
  String? name;
  String? profile;

  ItemRatingUser({this.id, this.name, this.profile});

  ItemRatingUser.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    name = json['name']?.toString();
    profile = json['profile']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['profile'] = profile;
    return data;
  }
}

class ItemRatingImages {
  String? id;
  String? productRatingId;
  String? image;
  String? imageUrl;

  ItemRatingImages({this.id, this.productRatingId, this.image, this.imageUrl});

  ItemRatingImages.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    productRatingId = json['product_rating_id']?.toString();
    image = json['image']?.toString();
    imageUrl = json['image_url']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product_rating_id'] = productRatingId;
    data['image'] = image;
    data['image_url'] = imageUrl;
    return data;
  }
}
