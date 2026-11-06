enum LayoutModeType {
  quick,
  ecommerce,
  both;

  static LayoutModeType fromRaw(String? raw) {
    switch (raw) {
      case 'quick':
        return LayoutModeType.quick;
      case 'ecommerce':
        return LayoutModeType.ecommerce;
      case 'both':
        return LayoutModeType.both;
      default:
        return LayoutModeType.quick;
    }
  }
}
