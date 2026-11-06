import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// Paginated API response wrapping the list of fund transfer entries.
class SettlementHistoryResponse {
  SettlementHistoryResponse({this.status, this.message, this.total, this.data});

  late final int? status;
  late final String? message;
  late final int? total;
  late final List<SettlementHistoryData>? data;

  SettlementHistoryResponse.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString() ?? "";
    total = toSafeIntOrNull(json['total']);
    data = json['data'] != null
        ? List.from(
            json['data'],
          ).map((e) => SettlementHistoryData.fromJson(e)).toList()
        : null;
  }
}

/// A single fund transfer/settlement entry.
class SettlementHistoryData {
  String? id;
  int? deliveryBoyId;
  String? name;
  String? mobile;
  String? countryCode;
  String? entryType;
  String? type;
  double? amount;
  double? openingBalance;
  double? closingBalance;
  String? currency;
  String? message;
  String? createdAt;

  SettlementHistoryData({
    this.id,
    this.deliveryBoyId,
    this.name,
    this.mobile,
    this.countryCode,
    this.entryType,
    this.type,
    this.amount,
    this.openingBalance,
    this.closingBalance,
    this.currency,
    this.message,
    this.createdAt,
  });

  SettlementHistoryData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    deliveryBoyId = toSafeIntOrNull(json['delivery_boy_id']);
    name = json['name']?.toString();
    mobile = json['mobile']?.toString();
    countryCode = json['country_code']?.toString();
    entryType = json['entry_type']?.toString();
    type = json['type']?.toString();
    amount = toSafeDouble(json['amount']);
    openingBalance = toSafeDouble(json['opening_balance']);
    closingBalance = toSafeDouble(json['closing_balance']);
    currency = json['currency']?.toString();
    message = json['message']?.toString();
    createdAt = json['created_at']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['delivery_boy_id'] = deliveryBoyId;
    data['name'] = name;
    data['mobile'] = mobile;
    data['country_code'] = countryCode;
    data['entry_type'] = entryType;
    data['type'] = type;
    data['amount'] = amount;
    data['opening_balance'] = openingBalance;
    data['closing_balance'] = closingBalance;
    data['currency'] = currency;
    data['message'] = message;
    data['created_at'] = createdAt;
    return data;
  }
}
