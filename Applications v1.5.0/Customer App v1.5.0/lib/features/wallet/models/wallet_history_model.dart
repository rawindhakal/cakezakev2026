import 'package:customer/utils/json_parsers.dart';

class WalletHistory {
  int? status;
  String? message;
  int? total;
  List<WalletHistoryData>? data;

  WalletHistory({this.status, this.message, this.total, this.data});

  WalletHistory.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    total = parseInt(json['total']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => WalletHistoryData.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['total'] = total;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class WalletHistoryData {
  String? id;
  String? orderId;
  String? orderItemId;
  String? userId;
  String? type;
  String? amount;
  String? txnId;
  String? paymentType;
  String? transactionDate;
  String? message;
  String? status;
  String? createdAt;
  String? updatedAt;
  String? lastUpdated;
  String? currency;
  String? currencyCode;

  WalletHistoryData({
    this.id,
    this.orderId,
    this.orderItemId,
    this.userId,
    this.type,
    this.amount,
    this.txnId,
    this.paymentType,
    this.transactionDate,
    this.message,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.lastUpdated,
    this.currency,
    this.currencyCode,
  });

  WalletHistoryData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    orderId = json['order_id']?.toString() ?? "";
    orderItemId = json['order_item_id']?.toString() ?? "";
    userId = json['user_id']?.toString() ?? "";
    type = json['type']?.toString() ?? "";
    amount = json['amount']?.toString() ?? "";
    txnId = parseString(json['txn_id']) ?? "";
    paymentType = parseString(json['payment_type']) ?? "";
    transactionDate = parseString(json['transaction_date']) ?? "";
    message = parseString(json['message']) ?? "";
    status = json['status']?.toString() ?? "";
    createdAt = json['created_at']?.toString() ?? "";
    updatedAt = json['updated_at']?.toString() ?? "";
    lastUpdated = json['last_updated']?.toString() ?? "";
    currency = parseString(json['currency']);
    currencyCode = parseString(json['currency_code']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['order_id'] = orderId;
    data['order_item_id'] = orderItemId;
    data['user_id'] = userId;
    data['type'] = type;
    data['amount'] = amount;
    data['txn_id'] = txnId;
    data['payment_type'] = paymentType;
    data['transaction_date'] = transactionDate;
    data['message'] = message;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['last_updated'] = lastUpdated;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    return data;
  }
}
