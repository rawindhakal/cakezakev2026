import 'package:deliveryboy/utils/extensions/num_extensions.dart';

class TaxCharges {
  String? name;
  double? rate;
  double? amount;
  double? taxableAmount;

  TaxCharges({this.name, this.rate, this.amount, this.taxableAmount});

  TaxCharges.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    rate = toSafeDoubleOrNull(json['rate']);
    amount = toSafeDoubleOrNull(json['amount']);
    taxableAmount = toSafeDoubleOrNull(json['taxable_amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['rate'] = rate;
    data['amount'] = amount;
    data['taxable_amount'] = taxableAmount;
    return data;
  }
}
