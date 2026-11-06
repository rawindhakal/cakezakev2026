import 'enums/promo_apply_type.dart';
import 'enums/promo_discount_type.dart';

class PromoCode {
  PromoCode({
    required this.status,
    required this.message,
    required this.total,
    required this.data,
  });

  late final String status;
  late final String message;
  late final String total;
  late final List<PromoCodeData> data;

  PromoCode.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    total = json['total']?.toString() ?? "";
    final rawData = json['data'];
    data = rawData is List
        ? rawData
              .map((e) => PromoCodeData.fromJson(e as Map<String, dynamic>))
              .toList()
        : <PromoCodeData>[];
  }

  Map<String, dynamic> toJson() {
    final itemData = <String, dynamic>{};
    itemData['status'] = status;
    itemData['message'] = message;
    itemData['total'] = total;
    itemData['data'] = data.map((e) => e.toJson()).toList();
    return itemData;
  }
}

class PromoCodeData {
  PromoCodeData({
    required this.id,
    required this.promoCodeId,
    required this.isApplicable,
    required this.message,
    required this.unlockMessage,
    required this.promoCode,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.total,
    required this.discount,
    required this.discountedAmount,
    required this.discountType,
    required this.discountApplyType,
    required this.maxDiscountAmount,
    required this.minimumOrderAmount,
    required this.minProductQuantity,
    required this.freeDelivery,
    required this.currency,
    required this.currencyCode,
    required this.decimalPoint,
  });

  late final int id;
  late final int promoCodeId;
  late final int isApplicable;
  late final String message;
  late final String unlockMessage;
  late final String promoCode;
  late final String title;
  late final String description;
  late final String imageUrl;
  late final double total;
  late final double discount;
  late final double discountedAmount;
  late final String discountType;

  PromoDiscountType get discountTypeEnum =>
      PromoDiscountType.fromRaw(discountType);
  late final String discountApplyType;

  PromoApplyType get discountApplyTypeEnum =>
      PromoApplyType.fromRaw(discountApplyType);
  late final double maxDiscountAmount;
  late final double minimumOrderAmount;
  late final int minProductQuantity;
  late final double freeDelivery;
  late final String currency;
  late final String currencyCode;
  late final int decimalPoint;

  PromoCodeData.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id']?.toString() ?? '') ?? 0;
    promoCodeId = int.tryParse(json['promo_code_id']?.toString() ?? '') ?? 0;
    isApplicable = int.tryParse(json['is_applicable']?.toString() ?? '') ?? 0;
    message = (json['message'] ?? '').toString();
    unlockMessage = (json['unlock_message'] ?? '').toString();
    promoCode = (json['promo_code'] ?? '').toString();
    title = (json['title'] ?? '').toString();
    description = (json['description'] ?? '').toString();
    imageUrl = (json['image_url'] ?? '').toString();
    total = double.tryParse(json['total']?.toString() ?? '0') ?? 0.0;
    discount = double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0;
    discountedAmount =
        double.tryParse(json['discounted_amount']?.toString() ?? '0') ?? 0.0;
    discountType = (json['discount_type'] ?? '').toString();
    discountApplyType = (json['discount_apply_type'] ?? '').toString();
    maxDiscountAmount =
        double.tryParse(json['max_discount_amount']?.toString() ?? '0') ?? 0.0;
    minimumOrderAmount =
        double.tryParse(json['minimum_order_amount']?.toString() ?? '0') ?? 0.0;
    minProductQuantity =
        int.tryParse(json['min_product_quantity']?.toString() ?? '0') ?? 0;
    freeDelivery =
        double.tryParse(json['free_delivery']?.toString() ?? '0') ?? 0;
    currency = (json['currency'] ?? '').toString();
    currencyCode = (json['currency_code'] ?? '').toString();
    decimalPoint = int.tryParse(json['decimal_point']?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'promo_code_id': promoCodeId,
    'is_applicable': isApplicable,
    'message': message,
    'unlock_message': unlockMessage,
    'promo_code': promoCode,
    'title': title,
    'description': description,
    'image_url': imageUrl,
    'total': total,
    'discount': discount,
    'discounted_amount': discountedAmount,
    'discount_type': discountType,
    'discount_apply_type': discountApplyType,
    'max_discount_amount': maxDiscountAmount,
    'minimum_order_amount': minimumOrderAmount,
    'min_product_quantity': minProductQuantity,
    'free_delivery': freeDelivery,
    'currency': currency,
    'currency_code': currencyCode,
    'decimal_point': decimalPoint,
  };
}
