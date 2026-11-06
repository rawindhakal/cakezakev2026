import 'package:deliveryboy/utils/extensions/num_extensions.dart';

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
    amount = toSafeDouble(json['amount']);
    taxableAmount = toSafeDouble(json['taxable_amount']);
    taxAmount = toSafeDouble(json['tax_amount']);
    taxName = toSafeString(json['tax_name']);
    taxRate = toSafeDouble(json['tax_rate']);
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
