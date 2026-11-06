import 'package:customer/features/products/models/product_model.dart';

class ProductDetailArgs {
  final int productId;
  final String? imageUrl;
  final String heroSuffix;

  /// Sibling products from the list the user tapped from, enabling
  /// horizontal swipe between products in the detail screen. Null/empty
  /// falls back to a single-product (no swipe) detail view.
  final List<ProductDataModel>? productList;

  /// Index of [productId] within [productList].
  final int initialIndex;

  const ProductDetailArgs({
    required this.productId,
    this.imageUrl,
    this.heroSuffix = '',
    this.productList,
    this.initialIndex = 0,
  });
}
