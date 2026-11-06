import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// A single salary payment entry.
class SalaryModel {
  int? id;
  double? amount;
  String? note;
  String? paidOn;
  String? currency;

  SalaryModel({this.id, this.amount, this.note, this.paidOn, this.currency});

  SalaryModel.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    amount = toSafeDouble(json['amount']);
    note = json['note']?.toString() ?? '';
    paidOn = json['paid_on']?.toString() ?? '';
    currency = json['currency']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'paid_on': paidOn,
      'currency': currency,
    };
  }
}
