enum PromoApplyType {
  instant,
  wallet,
  unknown;

  static PromoApplyType fromRaw(String? raw) {
    switch (raw) {
      case 'instant':
        return PromoApplyType.instant;
      case 'wallet':
        return PromoApplyType.wallet;
      default:
        return PromoApplyType.unknown;
    }
  }
}
