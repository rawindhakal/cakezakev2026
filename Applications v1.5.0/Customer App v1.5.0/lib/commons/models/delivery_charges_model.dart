import 'package:customer/utils/json_parsers.dart';

class DeliveryCharges {
  double? amount;
  double? taxableAmount;
  double? taxAmount;
  String? taxName;
  double? taxRate;

  DeliveryCharges({
    this.amount,
    this.taxableAmount,
    this.taxAmount,
    this.taxName,
    this.taxRate,
  });

  DeliveryCharges.fromJson(Map<String, dynamic> json) {
    amount = parseDouble(json['amount']);
    taxableAmount = parseDouble(json['taxable_amount']);
    taxAmount = parseDouble(json['tax_amount']);
    taxName = parseString(json['tax_name']) ?? "";
    taxRate = parseDouble(json['tax_rate']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['amount'] = amount;
    data['taxable_amount'] = taxableAmount;
    data['tax_amount'] = taxAmount;
    data['tax_name'] = taxName;
    data['tax_rate'] = taxRate;
    return data;
  }
}
