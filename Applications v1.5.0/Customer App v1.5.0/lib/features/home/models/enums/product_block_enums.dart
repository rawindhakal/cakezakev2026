enum ProductLayout {
  horizontal,
  list,
  grid;

  static ProductLayout fromRaw(String? raw) {
    switch (raw) {
      case 'horizontal':
        return ProductLayout.horizontal;
      case 'list':
        return ProductLayout.list;
      default:
        return ProductLayout.grid;
    }
  }
}

enum ProductVariant {
  defaultVariant,
  withTitle,
  withBackground,
  withColor;

  static ProductVariant fromRaw(String? raw) {
    switch (raw) {
      case 'with_title':
        return ProductVariant.withTitle;
      case 'with_background':
        return ProductVariant.withBackground;
      case 'with_color':
        return ProductVariant.withColor;
      default:
        return ProductVariant.defaultVariant;
    }
  }
}
