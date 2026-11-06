enum PromoDiscountType {
  flat,
  percentage,
  freeDelivery,
  unknown;

  static PromoDiscountType fromRaw(String? raw) {
    switch (raw) {
      case 'flat':
        return PromoDiscountType.flat;
      case 'percentage':
        return PromoDiscountType.percentage;
      case 'free_delivery':
        return PromoDiscountType.freeDelivery;
      default:
        return PromoDiscountType.unknown;
    }
  }
}
