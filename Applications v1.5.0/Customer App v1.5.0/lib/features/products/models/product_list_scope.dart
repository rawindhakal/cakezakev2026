/// Server-side scope of a home product row (product_slider block or one tab
/// of product_tabs). Passed through unchanged to View More so its list — and
/// the filter sheet's counts — match the row that was tapped.
class ProductListScope {
  final String? dataSource;

  /// Comma-separated, already includes child categories — never expand it.
  final String? categoryIds;
  final String? brandIds;

  /// "exclude" flips [categoryIds]/[brandIds] to "everything except these".
  /// Null when the server didn't send it — never default it.
  final String? filterMode;
  final String? manualProductIds;

  const ProductListScope({
    this.dataSource,
    this.categoryIds,
    this.brandIds,
    this.filterMode,
    this.manualProductIds,
  });
}

typedef ViewMoreTapCallback =
    void Function(String title, ProductListScope scope);
