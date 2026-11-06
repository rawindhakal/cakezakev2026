import 'package:customer/features/products/models/product_model.dart';

/// Resolves the product_variant_id key checkout uses for a cart item —
/// must match [CartCubit.seedFromApi]'s key and the place-order API's
/// expected id, else optimistic cart updates and prescription mapping
/// silently drift from what's actually submitted.
String resolveCheckoutVariantId(ProductDataModel item) {
  final v = item.variantId?.toString();
  if (v != null && v.isNotEmpty) return v;
  return item.variants?.isNotEmpty == true
      ? (item.variants!.first.id?.toString() ?? '')
      : '';
}
