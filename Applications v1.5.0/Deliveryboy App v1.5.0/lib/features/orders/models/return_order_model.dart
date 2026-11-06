import 'package:deliveryboy/features/orders/models/additional_charges_model.dart';
import 'package:deliveryboy/features/orders/models/address_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_boy_bonus_details_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_charges_model.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/models/tax_charges_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_status.dart';
import 'package:deliveryboy/features/orders/models/storeinfo_model.dart';
import 'package:deliveryboy/features/orders/models/surge_charges_model.dart';
import 'package:deliveryboy/features/orders/models/timeline_model.dart';
import 'package:deliveryboy/features/orders/models/variant_attributes_model.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';

export 'package:deliveryboy/features/orders/models/return_order_status.dart';

class ReturnRequestData {
  int? id;
  int? userId;
  int? productVariantId;
  int? orderId;
  int? orderItemId;
  int? addressId;
  Address? address;
  String? returnReason;
  int? status;
  String? remarks;
  int? deliveryBoyId;
  String? rejectReason;
  String? createdAt;
  String? updatedAt;
  double? deliveryBoyBonusAmount;
  DeliveryBoyBonusDetails? deliveryBoyBonusDetails;
  int? bonusCredited;
  String? customerName;
  String? customerMobile;
  String? customerEmail;
  int? quantity;
  double? price;
  double? subTotal;
  double? discountedPrice;
  String? productName;
  String? paymentMethod;
  double? finalTotal;
  String? currency;
  String? decimalPoint;
  String? returnNumber;
  int? zoneId;
  String? cityName;
  String? deliveryBoyName;
  String? deliveryBoyMobile;
  int? productId;
  String? orderStatusName;
  String? date;
  ReturnItem? returnItem;
  Address? pickupAddress;
  List<Timeline>? timeline;
  StoreInfo? storeInfo;

  ReturnRequestData({
    this.id,
    this.userId,
    this.productVariantId,
    this.orderId,
    this.orderItemId,
    this.addressId,
    this.address,
    this.returnReason,
    this.status,
    this.remarks,
    this.deliveryBoyId,
    this.rejectReason,
    this.createdAt,
    this.updatedAt,
    this.deliveryBoyBonusAmount,
    this.deliveryBoyBonusDetails,
    this.bonusCredited,
    this.customerName,
    this.customerMobile,
    this.customerEmail,
    this.quantity,
    this.price,
    this.subTotal,
    this.discountedPrice,
    this.productName,
    this.paymentMethod,
    this.finalTotal,
    this.currency,
    this.decimalPoint,
    this.returnNumber,
    this.zoneId,
    this.cityName,
    this.deliveryBoyName,
    this.deliveryBoyMobile,
    this.productId,
    this.orderStatusName,
    this.date,
    this.returnItem,
    this.pickupAddress,
    this.timeline,
    this.storeInfo,
  });

  ReturnRequestData.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    userId = toSafeIntOrNull(json['user_id']);
    productVariantId = toSafeIntOrNull(json['product_variant_id']);
    orderId = toSafeIntOrNull(json['order_id']);
    orderItemId = toSafeIntOrNull(json['order_item_id']);
    addressId = toSafeIntOrNull(json['address_id']);
    address = json['address'] != null
        ? Address.fromJson(json['address'])
        : null;
    returnReason = json['return_reason']?.toString();
    status = toSafeIntOrNull(json['status']);
    remarks = json['remarks']?.toString();
    deliveryBoyId = toSafeIntOrNull(json['delivery_boy_id']);
    rejectReason = json['reject_reason']?.toString();
    createdAt = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    deliveryBoyBonusAmount = toSafeDoubleOrNull(
      json['delivery_boy_bonus_amount'],
    );
    deliveryBoyBonusDetails = json['delivery_boy_bonus_details'] != null
        ? DeliveryBoyBonusDetails.fromJson(json['delivery_boy_bonus_details'])
        : null;
    bonusCredited = toSafeIntOrNull(json['bonus_credited']);
    customerName = json['customer_name']?.toString();
    customerMobile = json['customer_mobile']?.toString();
    customerEmail = json['customer_email']?.toString();
    quantity = toSafeIntOrNull(json['quantity']);
    price = toSafeDouble(json['price']);
    subTotal = toSafeDouble(json['sub_total']);
    discountedPrice = toSafeDouble(json['discounted_price']);
    productName = json['product_name']?.toString();
    paymentMethod = json['payment_method']?.toString();
    finalTotal = toSafeDouble(json['final_total']);
    currency = json['currency']?.toString();
    decimalPoint = json['decimal_point']?.toString();
    returnNumber = json['return_number']?.toString();
    zoneId = toSafeIntOrNull(json['zone_id']);
    cityName = json['city_name']?.toString();
    deliveryBoyName = json['delivery_boy_name']?.toString();
    deliveryBoyMobile = json['delivery_boy_mobile']?.toString();
    productId = toSafeIntOrNull(json['product_id']);
    orderStatusName = json['order_status_name']?.toString();
    date = json['date']?.toString();
    returnItem = json['return_item'] != null
        ? ReturnItem.fromJson(json['return_item'])
        : null;
    pickupAddress = json['pickup_address'] != null
        ? Address.fromJson(json['pickup_address'])
        : null;
    timeline = toSafeList(
      json['timeline'],
      (v) => Timeline.fromJson(v as Map<String, dynamic>),
    );
    storeInfo = json['branch_info'] != null
        ? StoreInfo.fromJson(json['branch_info'])
        : null;
  }

  ReturnOrderStatus get returnStatusEnum => ReturnOrderStatus.fromId(status);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['product_variant_id'] = productVariantId;
    data['order_id'] = orderId;
    data['order_item_id'] = orderItemId;
    data['address_id'] = addressId;
    if (address != null) {
      data['address'] = address!.toJson();
    }
    data['return_reason'] = returnReason;
    data['status'] = status;
    data['remarks'] = remarks;
    data['delivery_boy_id'] = deliveryBoyId;
    data['reject_reason'] = rejectReason;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['delivery_boy_bonus_amount'] = deliveryBoyBonusAmount;
    if (deliveryBoyBonusDetails != null) {
      data['delivery_boy_bonus_details'] = deliveryBoyBonusDetails!.toJson();
    }
    data['bonus_credited'] = bonusCredited;
    data['customer_name'] = customerName;
    data['customer_mobile'] = customerMobile;
    data['customer_email'] = customerEmail;
    data['quantity'] = quantity;
    data['price'] = price;
    data['sub_total'] = subTotal;
    data['discounted_price'] = discountedPrice;
    data['product_name'] = productName;
    data['payment_method'] = paymentMethod;
    data['final_total'] = finalTotal;
    data['currency'] = currency;
    data['decimal_point'] = decimalPoint;
    data['return_number'] = returnNumber;
    data['zone_id'] = zoneId;
    data['city_name'] = cityName;
    data['delivery_boy_name'] = deliveryBoyName;
    data['delivery_boy_mobile'] = deliveryBoyMobile;
    data['product_id'] = productId;
    data['order_status_name'] = orderStatusName;
    data['date'] = date;
    if (returnItem != null) {
      data['return_item'] = returnItem!.toJson();
    }
    if (pickupAddress != null) {
      data['pickup_address'] = pickupAddress!.toJson();
    }
    if (timeline != null) {
      data['timeline'] = timeline!.map((v) => v.toJson()).toList();
    }
    if (storeInfo != null) {
      data['branch_info'] = storeInfo!.toJson();
    }
    return data;
  }
}

class ReturnDetailResponse {
  int? status;
  String? message;
  ReturnRequestData? data;

  ReturnDetailResponse({this.status, this.message, this.data});

  ReturnDetailResponse.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    final raw = json['data'];
    if (raw is Map<String, dynamic>) {
      data = ReturnRequestData.fromJson(raw);
    } else if (raw is List && raw.isNotEmpty) {
      data = ReturnRequestData.fromJson(raw[0] as Map<String, dynamic>);
    }
  }
}

class ReturnItem {
  int? id;
  int? userId;
  int? orderId;
  String? productName;
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
  String? createdAt;
  String? updatedAt;
  String? deletedAt;
  String? mobile;
  double? total;
  double? discount;
  String? promoCode;
  String? paymentMethod;
  Address? address;
  String? userName;
  String? storeName;
  int? productId;
  String? image;
  String? statusName;
  double? amountToRefund;
  String? decimalPoint;

  // Add-on module: snapshot of the chosen options as they were when
  // ordered. `addon_total` is display-only — price / discounted_price /
  // sub_total already include the addons.
  List<OrderAddon>? addons;
  double? addonTotal;

  ReturnItem({
    this.id,
    this.userId,
    this.orderId,
    this.productName,
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
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.mobile,
    this.total,
    this.discount,
    this.promoCode,
    this.paymentMethod,
    this.address,
    this.userName,
    this.storeName,
    this.productId,
    this.image,
    this.statusName,
    this.amountToRefund,
    this.decimalPoint,
    this.addons,
    this.addonTotal,
  });

  ReturnItem.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    userId = toSafeIntOrNull(json['user_id']);
    orderId = toSafeIntOrNull(json['order_id']);
    productName = json['product_name']?.toString();
    variantAttributes = toSafeList(
      json['variant_attributes'],
      (v) => VariantAttributes.fromJson(v as Map<String, dynamic>),
    );
    productVariantId = toSafeIntOrNull(json['product_variant_id']);
    deliveryBoyId = toSafeIntOrNull(json['delivery_boy_id']);
    deliveryBoyBonusDetails = json['delivery_boy_bonus_details'] != null
        ? DeliveryBoyBonusDetails.fromJson(json['delivery_boy_bonus_details'])
        : null;
    deliveryBoyBonusAmount = toSafeDoubleOrNull(
      json['delivery_boy_bonus_amount'],
    );
    quantity = toSafeIntOrNull(json['quantity']);
    price = toSafeDouble(json['price']);
    discountedPrice = toSafeDouble(json['discounted_price']);
    taxAmount = toSafeDouble(json['tax_amount']);
    taxPercentage = toSafeDouble(json['tax_percentage']);
    subTotal = toSafeDouble(json['sub_total']);
    deliveryCharges = json['delivery_charges'] is Map<String, dynamic>
        ? DeliveryCharges.fromJson(json['delivery_charges'] as Map<String, dynamic>)
        : null;
    additionalCharges = toSafeList(
      json['additional_charges'],
      (v) => AdditionalCharges.fromJson(v as Map<String, dynamic>),
    );
    surgeCharges = toSafeList(
      json['surge_charges'],
      (v) => SurgeCharges.fromJson(v as Map<String, dynamic>),
    );
    taxBreakdown = toSafeList(
      json['tax_breakdown'],
      (v) => TaxCharges.fromJson(v as Map<String, dynamic>),
    );
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
    createdAt = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    deletedAt = json['deleted_at']?.toString();
    mobile = json['mobile']?.toString();
    total = toSafeDouble(json['total']);
    discount = toSafeDouble(json['discount']);
    promoCode = json['promo_code']?.toString();
    paymentMethod = json['payment_method']?.toString();
    address = json['address'] != null
        ? Address.fromJson(json['address'])
        : null;
    userName = json['user_name']?.toString();
    storeName = json['branch_name']?.toString();
    productId = toSafeIntOrNull(json['product_id']);
    image = json['image']?.toString();
    statusName = json['status_name']?.toString();
    amountToRefund = toSafeDouble(json['amount_to_refund']);
    decimalPoint = json['decimal_point']?.toString();
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
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    data['mobile'] = mobile;
    data['total'] = total;
    data['discount'] = discount;
    data['promo_code'] = promoCode;
    data['payment_method'] = paymentMethod;
    if (address != null) {
      data['address'] = address!.toJson();
    }
    data['user_name'] = userName;
    data['branch_name'] = storeName;
    data['product_id'] = productId;
    data['image'] = image;
    data['status_name'] = statusName;
    data['amount_to_refund'] = amountToRefund;
    data['decimal_point'] = decimalPoint;
    // Add-on module.
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
    return data;
  }
}
