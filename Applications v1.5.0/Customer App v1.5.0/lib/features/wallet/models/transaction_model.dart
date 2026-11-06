class Transaction {
  Transaction({
    required this.status,
    required this.message,
    required this.total,
    required this.data,
  });

  late final int status;
  late final String message;
  late final int total;
  late final List<TransactionData> data;

  Transaction.fromJson(Map<String, dynamic> json) {
    status = int.tryParse(json['status']?.toString() ?? '') ?? 0;
    message = json['message']?.toString() ?? "";
    total = int.tryParse(json['total']?.toString() ?? '') ?? 0;
    final rawData = json['data'];
    data = rawData is List
        ? rawData
              .map((e) => TransactionData.fromJson(e as Map<String, dynamic>))
              .toList()
        : <TransactionData>[];
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

class TransactionData {
  TransactionData({
    required this.id,
    required this.txnId,
    required this.type,
    required this.amount,
    required this.status,
    required this.message,
    required this.createdAt,
    this.currency,
    this.currencyCode,
  });

  late final String id;
  late final String txnId;
  late final String type;
  late final String amount;
  late final String status;
  late final String message;
  late final String createdAt;
  String? currency;
  String? currencyCode;

  TransactionData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    txnId = json['txn_id']?.toString() ?? "";
    type = json['type']?.toString() ?? "";
    amount = json['amount']?.toString() ?? "";
    status = json['status']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    createdAt = json['created_at']?.toString() ?? "";
    currency = json['currency']?.toString() ?? "";
    currencyCode = json['currency_code']?.toString();
  }

  Map<String, dynamic> toJson() {
    final itemData = <String, dynamic>{};
    itemData['id'] = id;
    itemData['txn_id'] = txnId;
    itemData['type'] = type;
    itemData['amount'] = amount;
    itemData['status'] = status;
    itemData['message'] = message;
    itemData['created_at'] = createdAt;
    itemData['currency'] = currency;
    itemData['currency_code'] = currencyCode;
    return itemData;
  }
}
