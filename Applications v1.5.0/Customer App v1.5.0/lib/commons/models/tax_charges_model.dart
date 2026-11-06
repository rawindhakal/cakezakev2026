import 'package:customer/utils/json_parsers.dart';

class TaxCharges {
  String? name;
  int? rate;
  double? amount;
  double? taxableAmount;

  TaxCharges({this.name, this.rate, this.amount, this.taxableAmount});

  TaxCharges.fromJson(Map<String, dynamic> json) {
    name = parseString(json['name']);
    rate = parseInt(json['rate']);
    amount = parseDoubleOrNull(json['amount']);
    taxableAmount = parseDoubleOrNull(json['taxable_amount']);
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
