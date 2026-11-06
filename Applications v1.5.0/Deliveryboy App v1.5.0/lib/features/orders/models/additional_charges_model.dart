import 'package:deliveryboy/utils/extensions/num_extensions.dart';

class AdditionalCharges {
  String? name;
  double? amount;
  bool? isRefundable;
  double? taxableAmount;
  double? taxAmount;
  String? taxName;
  double? taxRate;

  AdditionalCharges({this.name, this.amount, this.isRefundable, this.taxableAmount, this.taxAmount, this.taxName, this.taxRate});

  AdditionalCharges.fromJson(Map<String, dynamic> json) {
    name = toSafeString(json['name']);
    amount = toSafeDouble(json['amount']);
    isRefundable = toSafeBool(json['is_refundable']);
    taxableAmount = toSafeDouble(json['taxable_amount']);
    taxAmount = toSafeDouble(json['tax_amount']);
    taxName = toSafeString(json['tax_name']);
    taxRate = toSafeDouble(json['tax_rate']);
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
