/// Payload holding the withdrawal-request list and current wallet balance.
class Data {
  List<WithdrawRequests>? withdrawRequests;
  String? balance;

  Data({this.withdrawRequests, this.balance});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['withdraw_requests'] != null) {
      withdrawRequests = <WithdrawRequests>[];
      json['withdraw_requests'].forEach((v) {
        withdrawRequests!.add(WithdrawRequests.fromJson(v));
      });
    }
    balance = json['balance']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (withdrawRequests != null) {
      data['withdraw_requests'] = withdrawRequests!
          .map((v) => v.toJson())
          .toList();
    }
    data['balance'] = balance;
    return data;
  }
}

/// A single wallet withdrawal-request transaction.
class WithdrawRequests {
  String? id;
  String? type;
  String? name;
  String? balance;
  String? amount;
  String? message;
  String? status;
  String? remark;
  String? receiptImageUrl;
  String? deviceType;
  String? createdAt;
  String? currency;

  WithdrawRequests({
    this.id,
    this.type,
    this.name,
    this.balance,
    this.amount,
    this.message,
    this.status,
    this.remark,
    this.receiptImageUrl,
    this.deviceType,
    this.createdAt,
    this.currency,
  });

  WithdrawRequests.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    type = json['type']?.toString();
    name = json['name']?.toString();
    balance = json['balance']?.toString();
    amount = json['amount']?.toString();
    message = json['message']?.toString();
    status = json['status']?.toString();
    remark = json['remark']?.toString();
    receiptImageUrl = json['receipt_image_url']?.toString();
    deviceType = json['device_type']?.toString();
    createdAt = json['created_at']?.toString();
    currency = json['currency']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    data['name'] = name;
    data['balance'] = balance;
    data['amount'] = amount;
    data['message'] = message;
    data['status'] = status;
    data['remark'] = remark;
    data['receipt_image_url'] = receiptImageUrl;
    data['device_type'] = deviceType;
    data['created_at'] = createdAt;
    data['currency'] = currency;
    return data;
  }
}
