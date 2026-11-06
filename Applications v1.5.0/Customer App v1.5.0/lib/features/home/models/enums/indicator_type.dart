enum IndicatorType {
  dots,
  none;

  static IndicatorType fromRaw(String? raw) {
    switch (raw) {
      case 'dots':
        return IndicatorType.dots;
      default:
        return IndicatorType.none;
    }
  }
}
