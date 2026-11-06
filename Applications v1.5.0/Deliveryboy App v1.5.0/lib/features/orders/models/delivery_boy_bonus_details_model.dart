import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// Delivery-boy bonus payout for an order/item. `final_total` comes from
/// quick and ecommerce order APIs; `base_total` comes from the return-order
/// API. Both are kept so one model works for every source without dropping
/// whichever total the caller actually sent.
class DeliveryBoyBonusDetails {
  double? finalTotal;
  double? baseTotal;
  int? bonusType;
  String? bonusTypeName;
  double? bonusAmount;

  DeliveryBoyBonusDetails({
    this.finalTotal,
    this.baseTotal,
    this.bonusType,
    this.bonusTypeName,
    this.bonusAmount,
  });

  DeliveryBoyBonusDetails.fromJson(Map<String, dynamic> json) {
    finalTotal = toSafeDouble(json['final_total']);
    baseTotal = toSafeDouble(json['base_total']);
    bonusType = toSafeIntOrNull(json['bonus_type']);
    bonusTypeName = json['bonus_type_name']?.toString();
    bonusAmount = toSafeDouble(json['bonus_amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['final_total'] = finalTotal;
    data['base_total'] = baseTotal;
    data['bonus_type'] = bonusType;
    data['bonus_type_name'] = bonusTypeName;
    data['bonus_amount'] = bonusAmount;
    return data;
  }
}
