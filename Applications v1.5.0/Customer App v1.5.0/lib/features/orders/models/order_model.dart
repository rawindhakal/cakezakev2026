import 'package:customer/commons/models/additional_charges_model.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/commons/models/delivery_charges_model.dart';
import 'package:customer/commons/models/surge_charges_model.dart';
import 'package:customer/commons/models/tax_charges_model.dart';
import 'package:customer/features/orders/models/order_address_model.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/utils/json_parsers.dart';

/// Delivery boy's current position, polled from `/live_tracking?order_id=`.
class LiveLocation {
  double? latitude;
  double? longitude;
  String? distance;
  String? distanceUnit;
  String? timeToDeliver;

  LiveLocation({
    this.latitude,
    this.longitude,
    this.distance,
    this.distanceUnit,
    this.timeToDeliver,
  });

  LiveLocation.fromJson(Map<String, dynamic> json) {
    latitude = double.tryParse(json['latitude']?.toString() ?? '');
    longitude = double.tryParse(json['longitude']?.toString() ?? '');
    distance = parseString(json['distance']);
    distanceUnit = parseString(json['distance_unit']);
    timeToDeliver = parseString(json['time_to_deliver']);
  }

  bool get isValid =>
      latitude != null &&
      longitude != null &&
      (latitude != 0 || longitude != 0);
}

/// Pickup order's fulfillment store — same shape as the cart response's
/// `pickup` object minus the per-cart `available`/`unavailable_reason`/
/// `distance` fields (an already-placed order's store doesn't need those).
class OrderPickupStore {
  int? branchId;
  String? branchName;
  String? address;
  double? latitude;
  double? longitude;
  String? contactNumber;
  int? preparationMinutes;
  String? preparationTime;
  bool? isOpenNow;

  OrderPickupStore({
    this.branchId,
    this.branchName,
    this.address,
    this.latitude,
    this.longitude,
    this.contactNumber,
    this.preparationMinutes,
    this.preparationTime,
    this.isOpenNow,
  });

  OrderPickupStore.fromJson(Map<String, dynamic> json) {
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
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'branch_id': branchId,
      'branch_name': branchName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contact_number': contactNumber,
      'preparation_minutes': preparationMinutes,
      'preparation_time': preparationTime,
      'is_open_now': isOpenNow,
    };
  }
}

class OrderModel {
  int? status;
  String? message;
  List<OrderData>? data;
  int? total;

  OrderModel({this.status, this.message, this.data, this.total});

  OrderModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => OrderData.fromJson(v as Map<String, dynamic>))
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
  DeliveryCharges? deliveryCharge;
  double? taxAmount;
  double? taxPercentage;
  double? walletBalance;
  double? paidWallet;
  double? discount;
  int? promoCodeId;
  String? promoCode;
  double? promoDiscount;
  double? cashbackAmount;
  int? cashbackCredited;
  List<AdditionalCharges>? additionalCharges;
  List<TaxCharges>? taxBreakdown;
  List<SurgeCharges>? surgeCharges;
  double? finalTotal;
  String? currency;
  String? currencyCode;
  int? decimalPoint;
  String? paymentMethod;
  OrderAddressModel? address;
  List<Timeline>? timeline;
  int? activeStatus;
  String? channel;
  double? remainingTotal;
  double? remainingFinal;
  String? createdAt;
  String? orderAddress;
  String? orderMobile;
  int? orderId;
  String? orderNumber;
  String? deliveryBoyName;
  String? deliveryBoyMobile;
  String? userName;
  String? orderStatusName;
  bool? productRating;
  String? date;
  List<OrderItems>? items;
  bool? isCancellable;
  bool? isDeliveryBoyChatVisible;
  double? savedAmount;
  double? refundAmount;
  String? cancellationReason;
  String? totalDeliverTime;
  String? preparationTime;
  String? timeToDeliver;

  /// 'delivery' | 'pickup'. `pickupStore` is null for delivery orders.
  String? deliveryType;
  OrderPickupStore? pickupStore;

  /// Buyer tax fields returned per order by `customer/orders` (and the
  /// ecommerce order list) and printed by the admin order view + both invoice
  /// templates. All three are `null` on a consumer order — then nothing new
  /// is rendered.
  ///
  /// Number frozen at order placement.
  String? buyerTaxNumber;

  /// Wording at the time of the order, e.g. `GSTIN`. Stored WITH the order on
  /// purpose: an admin can later change the country's label, and an old
  /// order keeps the word it was issued under — always print this one, never
  /// the current `country_setting` label.
  String? buyerTaxLabel;

  /// Name the invoice is billed in.
  String? buyerBusinessName;

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
    this.deliveryCharge,
    this.taxAmount,
    this.taxPercentage,
    this.walletBalance,
    this.paidWallet,
    this.discount,
    this.promoCodeId,
    this.promoCode,
    this.promoDiscount,
    this.cashbackAmount,
    this.cashbackCredited,
    this.additionalCharges,
    this.taxBreakdown,
    this.surgeCharges,
    this.finalTotal,
    this.currency,
    this.currencyCode,
    this.decimalPoint,
    this.paymentMethod,
    this.address,
    this.timeline,
    this.activeStatus,
    this.channel,
    this.remainingTotal,
    this.remainingFinal,
    this.createdAt,
    this.orderAddress,
    this.orderMobile,
    this.orderId,
    this.orderNumber,
    this.deliveryBoyName,
    this.deliveryBoyMobile,
    this.userName,
    this.orderStatusName,
    this.productRating,
    this.date,
    this.items,
    this.isCancellable,
    this.isDeliveryBoyChatVisible,
    this.savedAmount,
    this.refundAmount,
    this.cancellationReason,
    this.totalDeliverTime,
    this.preparationTime,
    this.timeToDeliver,
    this.deliveryType,
    this.pickupStore,
    this.buyerTaxNumber,
    this.buyerTaxLabel,
    this.buyerBusinessName,
  });

  OrderData.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    userId = parseInt(json['user_id']);
    deliveryBoyId = parseInt(json['delivery_boy_id']);
    deliveryBoyBonusDetails =
        json['delivery_boy_bonus_details'] is Map<String, dynamic>
        ? DeliveryBoyBonusDetails.fromJson(
            json['delivery_boy_bonus_details'] as Map<String, dynamic>,
          )
        : null;
    deliveryBoyBonusAmount = parseDouble(json['delivery_boy_bonus_amount']);
    transactionId = parseInt(json['transaction_id']);
    otp = parseInt(json['otp']);
    mobile = parseString(json['mobile']);
    orderNote = parseString(json['order_note']);
    deliveryDate = parseString(json['delivery_date']);
    deliverySlot = parseString(json['delivery_slot']);
    total = parseDouble(json['total']);
    deliveryCharge = json['delivery_charges'] is Map<String, dynamic>
        ? DeliveryCharges.fromJson(
            json['delivery_charges'] as Map<String, dynamic>,
          )
        : null;
    taxAmount = parseDouble(json['tax_amount']);
    taxPercentage = parseDouble(json['tax_percentage']);
    walletBalance = parseDouble(json['wallet_balance']);
    paidWallet = parseDouble(json['paid_wallet']);
    discount = parseDouble(json['discount']);
    promoCodeId = parseInt(json['promo_code_id']);
    promoCode = parseString(json['promo_code']);
    promoDiscount = parseDouble(json['promo_discount']);
    cashbackAmount = parseDouble(json['cashback_amount']);
    cashbackCredited = parseInt(json['cashback_credited']);
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
    finalTotal = parseDouble(json['final_total']);
    currency = parseString(json['currency']);
    currencyCode = parseString(json['currency_code']);
    decimalPoint = parseInt(json['decimal_point']);
    paymentMethod = parseString(json['payment_method']);
    address = json['address'] is Map<String, dynamic>
        ? OrderAddressModel.fromJson(json['address'] as Map<String, dynamic>)
        : null;
    buyerTaxNumber = parseString(json['buyer_tax_number']);
    buyerTaxLabel = parseString(json['buyer_tax_label']);
    buyerBusinessName = parseString(json['buyer_business_name']);
    final rawTimeline = json['timeline'];
    if (rawTimeline is List) {
      timeline = rawTimeline
          .map((v) => Timeline.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    activeStatus = parseInt(json['active_status']);
    channel = parseString(json['channel']);
    remainingTotal = parseDouble(json['remaining_total']);
    remainingFinal = parseDouble(json['remaining_final']);
    createdAt = parseString(json['created_at']);
    orderAddress = parseString(json['order_address']);
    orderMobile = parseString(json['order_mobile']);
    orderId = parseInt(json['order_id']);
    orderNumber = parseString(json['order_number']);
    deliveryBoyName = parseString(json['delivery_boy_name']);
    deliveryBoyMobile = parseString(json['delivery_boy_mobile']);
    userName = parseString(json['user_name']);
    orderStatusName = parseString(json['order_status_name']);
    productRating = parseBool(json['product_rating']);
    date = parseString(json['date']);
    final rawItems = json['items'];
    if (rawItems is List) {
      items = rawItems
          .map((v) => OrderItems.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    isCancellable = parseBool(json['is_cancellable']) ?? false;
    isDeliveryBoyChatVisible =
        parseBool(json['is_delivery_boy_chat_visible']) ?? false;
    savedAmount = parseDouble(json['saved_amount']);
    refundAmount = parseDouble(json['refund_amount']);
    cancellationReason = parseString(json['cancellation_reason']);
    if (cancellationReason == null || cancellationReason!.isEmpty) {
      cancellationReason = items
          ?.map((i) => i.cancellationReason)
          .firstWhere((r) => r != null && r.isNotEmpty, orElse: () => null);
    }
    totalDeliverTime = parseString(json['total_deliver_time']);
    preparationTime = parseString(json['preparation_time']);
    timeToDeliver = parseString(json['time_to_deliver']);
    deliveryType = parseString(json['delivery_type']);
    // Store → Branch rename (1.5.0); `pickup_store` kept as a read fallback
    // since the rename checklist doesn't list this object key.
    final rawPickup = json['pickup_branch'] ?? json['pickup_store'];
    pickupStore = rawPickup is Map<String, dynamic>
        ? OrderPickupStore.fromJson(rawPickup)
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
    data['delivery_charges'] = deliveryCharge?.toJson();
    data['tax_amount'] = taxAmount;
    data['tax_percentage'] = taxPercentage;
    data['wallet_balance'] = walletBalance;
    data['paid_wallet'] = paidWallet;
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
    if (taxBreakdown != null) {
      data['tax_breakdown'] = taxBreakdown!.map((v) => v.toJson()).toList();
    }
    if (surgeCharges != null) {
      data['surge_charges'] = surgeCharges!.map((v) => v.toJson()).toList();
    }
    data['final_total'] = finalTotal;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['decimal_point'] = decimalPoint;
    data['payment_method'] = paymentMethod;
    if (address != null) data['address'] = address!.toJson();
    if (timeline != null) {
      data['timeline'] = timeline!.map((v) => v.toJson()).toList();
    }
    data['active_status'] = activeStatus;
    data['channel'] = channel;
    data['remaining_total'] = remainingTotal;
    data['remaining_final'] = remainingFinal;
    data['created_at'] = createdAt;
    data['order_address'] = orderAddress;
    data['order_mobile'] = orderMobile;
    data['order_id'] = orderId;
    data['order_number'] = orderNumber;
    data['delivery_boy_name'] = deliveryBoyName;
    data['delivery_boy_mobile'] = deliveryBoyMobile;
    data['user_name'] = userName;
    data['order_status_name'] = orderStatusName;
    data['product_rating'] = productRating;
    data['date'] = date;
    if (items != null) {
      data['items'] = items!.map((v) => v.toJson()).toList();
    }
    data['is_cancellable'] = isCancellable;
    data['is_delivery_boy_chat_visible'] = isDeliveryBoyChatVisible;
    data['saved_amount'] = savedAmount;
    data['refund_amount'] = refundAmount;
    data['cancellation_reason'] = cancellationReason;
    data['total_deliver_time'] = totalDeliverTime;
    data['preparation_time'] = preparationTime;
    data['time_to_deliver'] = timeToDeliver;
    data['delivery_type'] = deliveryType;
    data['pickup_branch'] = pickupStore?.toJson();
    return data;
  }
}

class OrderItems {
  int? id;
  int? userId;
  int? orderId;
  String? ordersId;
  String? productName;
  int? productType;
  List<VariantAttributes>? variantAttributes;
  int? productVariantId;
  int? deliveryBoyId;
  int? quantity;
  double? price;
  double? discountedPrice;
  double? taxAmount;
  int? taxPercentage;
  double? subTotal;
  double? refundAmount;
  int? activeStatus;
  String? cancellationReason;
  String? canceledAt;
  int? branchId;
  int? isCredited;
  String? createdAt;
  int? variantId;
  int? productId;
  String? name;
  String? manufacturer;
  String? madeIn;
  int? returnStatus;
  int? returnDays;
  int? cancelableStatus;
  int? tillStatus;
  String? branchName;
  String? branchAddress;
  String? branchLatitude;
  String? branchLongitude;
  int? returnRequested;
  String? returnReason;
  String? returnRemarks;
  double? effectivePrice;
  List<ItemRating>? itemRating;
  String? imageUrl;
  String? prescriptionUrl;

  // Add-on module: snapshot of the chosen options as they were when
  // ordered. `addon_total` is display-only — price / discounted_price /
  // sub_total already include the addons.
  List<CartAddon>? addons;
  double? addonTotal;

  OrderItems({
    this.id,
    this.userId,
    this.orderId,
    this.ordersId,
    this.productName,
    this.productType,
    this.variantAttributes,
    this.productVariantId,
    this.deliveryBoyId,
    this.quantity,
    this.price,
    this.discountedPrice,
    this.taxAmount,
    this.taxPercentage,
    this.subTotal,
    this.refundAmount,
    this.activeStatus,
    this.cancellationReason,
    this.canceledAt,
    this.branchId,
    this.isCredited,
    this.createdAt,
    this.variantId,
    this.productId,
    this.name,
    this.manufacturer,
    this.madeIn,
    this.returnStatus,
    this.returnDays,
    this.cancelableStatus,
    this.tillStatus,
    this.branchName,
    this.branchAddress,
    this.branchLatitude,
    this.branchLongitude,
    this.returnRequested,
    this.returnReason,
    this.returnRemarks,
    this.effectivePrice,
    this.itemRating,
    this.imageUrl,
    this.prescriptionUrl,
    this.addons,
    this.addonTotal,
  });

  OrderItems.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    userId = parseInt(json['user_id']);
    orderId = parseInt(json['order_id']);
    ordersId = parseString(json['orders_id']);
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
    quantity = parseInt(json['quantity']);
    price = parseDouble(json['price']);
    discountedPrice = parseDouble(json['discounted_price']);
    taxAmount = parseDouble(json['tax_amount']);
    taxPercentage = parseInt(json['tax_percentage']);
    subTotal = parseDouble(json['sub_total']);
    refundAmount = parseDouble(json['refund_amount']);
    activeStatus = parseInt(json['active_status']);
    cancellationReason = parseString(json['cancellation_reason']);
    canceledAt = parseString(json['canceled_at']);
    branchId = parseInt(json['branch_id']);
    isCredited = parseInt(json['is_credited']);
    createdAt = parseString(json['created_at']);
    variantId = parseInt(json['variant_id']);
    productId = parseInt(json['product_id']);
    name = parseString(json['name']);
    manufacturer = parseString(json['manufacturer']);
    madeIn = parseString(json['made_in']);
    returnStatus = parseInt(json['return_status']);
    returnDays = parseInt(json['return_days']);
    cancelableStatus = parseInt(json['cancelable_status']);
    tillStatus = parseInt(json['till_status']);
    branchName = parseString(json['branch_name']);
    branchAddress = parseString(json['branch_address']);
    branchLatitude = parseString(json['branch_latitude']);
    branchLongitude = parseString(json['branch_longitude']);
    returnRequested = parseInt(json['return_requested']);
    returnReason = parseString(json['return_reason']);
    returnRemarks = parseString(json['return_remarks']);
    effectivePrice = parseDouble(json['effective_price']);
    final rawItemRating = json['item_rating'];
    if (rawItemRating is List) {
      itemRating = rawItemRating
          .map((v) => ItemRating.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    imageUrl = parseString(json['image_url']);
    prescriptionUrl = parseString(json['prescription_url']) ?? "";
    // Add-on module.
    addons = parseCartAddons(json['addons']);
    addonTotal = parseDouble(json['addon_total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['order_id'] = orderId;
    data['orders_id'] = ordersId;
    data['product_name'] = productName;
    data['product_type'] = productType;
    if (variantAttributes != null) {
      data['variant_attributes'] = variantAttributes!
          .map((v) => v.toJson())
          .toList();
    }
    data['product_variant_id'] = productVariantId;
    data['delivery_boy_id'] = deliveryBoyId;
    data['quantity'] = quantity;
    data['price'] = price;
    data['discounted_price'] = discountedPrice;
    data['tax_amount'] = taxAmount;
    data['tax_percentage'] = taxPercentage;
    data['sub_total'] = subTotal;
    data['refund_amount'] = refundAmount;
    data['active_status'] = activeStatus;
    data['cancellation_reason'] = cancellationReason;
    data['canceled_at'] = canceledAt;
    data['branch_id'] = branchId;
    data['is_credited'] = isCredited;
    data['created_at'] = createdAt;
    data['variant_id'] = variantId;
    data['product_id'] = productId;
    data['name'] = name;
    data['manufacturer'] = manufacturer;
    data['made_in'] = madeIn;
    data['return_status'] = returnStatus;
    data['return_days'] = returnDays;
    data['cancelable_status'] = cancelableStatus;
    data['till_status'] = tillStatus;
    data['branch_name'] = branchName;
    data['branch_address'] = branchAddress;
    data['branch_latitude'] = branchLatitude;
    data['branch_longitude'] = branchLongitude;
    data['return_requested'] = returnRequested;
    data['return_reason'] = returnReason;
    data['return_remarks'] = returnRemarks;
    data['effective_price'] = effectivePrice;
    if (itemRating != null) {
      data['item_rating'] = itemRating!.map((v) => v.toJson()).toList();
    }
    data['image_url'] = imageUrl;
    data['prescription_url'] = prescriptionUrl;
    // Add-on module.
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
    return data;
  }
}

class VariantAttributes {
  String? name;
  String? value;

  VariantAttributes({this.name, this.value});

  VariantAttributes.fromJson(Map<String, dynamic> json) {
    name = parseString(json['name']);
    value = parseString(json['value']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['value'] = value;
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
    id = parseString(json['id']);
    productId = parseString(json['product_id']);
    userId = parseString(json['user_id']);
    rate = parseString(json['rate']);
    review = parseString(json['review']);
    status = parseString(json['status']);
    updatedAt = parseString(json['updated_at']);
    user = json['user'] is Map<String, dynamic>
        ? ItemRatingUser.fromJson(json['user'] as Map<String, dynamic>)
        : null;
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages
          .map((v) => ItemRatingImages.fromJson(v as Map<String, dynamic>))
          .toList();
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
    id = parseString(json['id']);
    name = parseString(json['name']);
    profile = parseString(json['profile']);
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
    id = parseString(json['id']);
    productRatingId = parseString(json['product_rating_id']);
    image = parseString(json['image']);
    imageUrl = parseString(json['image_url']);
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
