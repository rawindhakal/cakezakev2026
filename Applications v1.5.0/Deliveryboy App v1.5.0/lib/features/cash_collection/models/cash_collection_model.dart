/// Extra summary payload carried alongside the paginated list via [PaginatedResponse.meta].
class CashCollectionMeta {
  final dynamic cashInHand;
  final dynamic cashCollected;

  const CashCollectionMeta({this.cashInHand, this.cashCollected});
}

/// Payload holding the cash collection list plus cash-in-hand/collected totals.
class CashCollectionData {
  CashCollectionData({
    this.cashCollections,
    this.cashInHand,
    this.cashCollected,
  });

  late final List<CashCollectionModel>? cashCollections;
  late final dynamic cashInHand;
  late final dynamic cashCollected;

  CashCollectionData.fromJson(Map<String, dynamic> json) {
    cashCollections = json['transactions'] != null
        ? List.from(
            json['transactions'],
          ).map((e) => CashCollectionModel.fromJson(e)).toList()
        : [];
    cashInHand = json['cash_in_hand'];
    cashCollected = json['cash_collected'];
  }
}

/// A single cash collection transaction entry.
class CashCollectionModel {
  String? id;
  String? userId;
  String? deliveryBoyId;
  String? deliveryBoyBonusDetails;
  String? deliveryBoyBonusAmount;
  String? transactionId;
  String? ordersId;
  String? otp;
  String? mobile;
  String? orderNote;
  String? total;
  String? deliveryCharge;
  String? taxAmount;
  String? taxPercentage;
  String? walletBalance;
  String? discount;
  String? promoCodeId;
  String? promoCode;
  String? promoDiscount;
  String? finalTotal;
  String? paymentMethod;
  String? address;
  String? latitude;
  String? longitude;
  String? deliveryTime;
  String? deliveryInstruction;
  String? status;
  String? activeStatus;
  String? orderFrom;
  String? pincodeId;
  String? addressId;
  String? areaId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;
  String? orderId;
  String? type;
  String? amount;
  String? message;
  String? transactionDate;
  String? name;
  String? collectedAmount;
  String? currency;

  CashCollectionModel({
    this.id,
    this.userId,
    this.deliveryBoyId,
    this.deliveryBoyBonusDetails,
    this.deliveryBoyBonusAmount,
    this.transactionId,
    this.ordersId,
    this.otp,
    this.mobile,
    this.orderNote,
    this.total,
    this.deliveryCharge,
    this.taxAmount,
    this.taxPercentage,
    this.walletBalance,
    this.discount,
    this.promoCodeId,
    this.promoCode,
    this.promoDiscount,
    this.finalTotal,
    this.paymentMethod,
    this.address,
    this.latitude,
    this.longitude,
    this.deliveryTime,
    this.deliveryInstruction,
    this.status,
    this.activeStatus,
    this.orderFrom,
    this.pincodeId,
    this.addressId,
    this.areaId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.orderId,
    this.type,
    this.amount,
    this.message,
    this.transactionDate,
    this.name,
    this.collectedAmount,
    this.currency,
  });

  CashCollectionModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    userId = json['user_id']?.toString();
    deliveryBoyId = json['delivery_boy_id']?.toString();
    deliveryBoyBonusDetails = json['delivery_boy_bonus_details']?.toString();
    deliveryBoyBonusAmount = json['delivery_boy_bonus_amount']?.toString();
    transactionId = json['transaction_id']?.toString();
    ordersId = json['orders_id']?.toString();
    otp = json['otp']?.toString();
    mobile = json['mobile']?.toString();
    orderNote = json['order_note']?.toString() ?? '';
    total = json['total']?.toString();
    deliveryCharge = json['delivery_charge']?.toString();
    taxAmount = json['tax_amount']?.toString();
    taxPercentage = json['tax_percentage']?.toString();
    walletBalance = json['wallet_balance']?.toString();
    discount = json['discount']?.toString();
    promoCodeId = json['promo_code_id']?.toString();
    promoCode = json['promo_code']?.toString();
    promoDiscount = json['promo_discount']?.toString();
    finalTotal = json['final_total']?.toString();
    paymentMethod = json['payment_method']?.toString();
    address = json['address']?.toString();
    latitude = json['latitude']?.toString();
    longitude = json['longitude']?.toString();
    deliveryTime = json['delivery_time']?.toString();
    deliveryInstruction = json['delivery_instruction']?.toString();
    status = json['status']?.toString();
    activeStatus = json['active_status']?.toString();
    orderFrom = json['order_from']?.toString();
    pincodeId = json['pincode_id']?.toString();
    addressId = json['address_id']?.toString();
    areaId = json['area_id']?.toString();
    createdAt = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    deletedAt = json['deleted_at']?.toString();
    orderId = json['order_id']?.toString();
    type = json['type']?.toString();
    amount = json['amount']?.toString();
    message = json['message']?.toString();
    transactionDate = json['transaction_date']?.toString();
    name = json['name']?.toString();
    collectedAmount = json['collected_amount']?.toString();
    currency = json['currency']?.toString();
  }
}
