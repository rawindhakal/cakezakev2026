enum RedirectType {
  product,
  category,
  brand,
  page,
  // Filtered product list — opens ProductScreen with redirect_params.
  products,
  none,
  unknown;

  static RedirectType fromRaw(String? raw) {
    switch (raw) {
      case 'product':
        return RedirectType.product;
      case 'category':
        return RedirectType.category;
      case 'brand':
        return RedirectType.brand;
      case 'page':
        return RedirectType.page;
      case 'products':
        return RedirectType.products;
      case 'none':
        return RedirectType.none;
      case null:
        return RedirectType.none;
      default:
        return RedirectType.unknown;
    }
  }
}
