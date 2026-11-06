import 'package:customer/utils/json_parsers.dart';

class AdditionalCharges {
  String? name;
  double? amount;
  bool? isRefundable;
  double? taxableAmount;
  double? taxAmount;
  String? taxName;
  double? taxRate;

  AdditionalCharges({
    this.name,
    this.amount,
    this.isRefundable,
    this.taxableAmount,
    this.taxAmount,
    this.taxName,
    this.taxRate,
  });

  AdditionalCharges.fromJson(Map<String, dynamic> json) {
    name = parseString(json['name']) ?? "";
    amount = parseDouble(json['amount']);
    isRefundable = parseBool(json['is_refundable']);
    taxableAmount = parseDouble(json['taxable_amount']);
    taxAmount = parseDouble(json['tax_amount']);
    taxName = parseString(json['tax_name']) ?? "";
    taxRate = parseDouble(json['tax_rate']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['amount'] = amount;
    data['is_refundable'] = isRefundable;
    data['taxable_amount'] = taxableAmount;
    data['tax_amount'] = taxAmount;
    data['tax_name'] = taxName;
    data['tax_rate'] = taxRate;
    return data;
  }
}
