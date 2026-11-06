import 'package:deliveryboy/utils/extensions/num_extensions.dart';

class SurgeCharges {
  String? label;
  double? charge;
  bool? isRefundable;
  double? taxableAmount;
  double? taxAmount;
  String? taxName;
  double? taxRate;

  SurgeCharges({this.label, this.charge, this.isRefundable, this.taxableAmount, this.taxAmount, this.taxName, this.taxRate});

  SurgeCharges.fromJson(Map<String, dynamic> json) {
    label = toSafeString(json['label']);
    charge = toSafeDouble(json['charge']);
    isRefundable = toSafeBool(json['is_refundable']);
    taxableAmount = toSafeDouble(json['taxable_amount']);
    taxAmount = toSafeDouble(json['tax_amount']);
    taxName = toSafeString(json['tax_name']);
    taxRate = toSafeDouble(json['tax_rate']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['label'] = label;
    data['charge'] = charge;
    data['is_refundable'] = isRefundable;
    data['taxable_amount'] = taxableAmount;
    data['tax_amount'] = taxAmount;
    data['tax_name'] = taxName;
    data['tax_rate'] = taxRate;
    return data;
  }
}
