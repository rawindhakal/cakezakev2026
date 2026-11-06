import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/cart/cubit/cart_recommendations_cubit.dart';
import 'package:customer/features/products/widgets/product_grid_section.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Upgrade your order" upsell grid, shown above Similar Products. Backed
/// by the same cart-wide [CartRecommendationsCubit] used at checkout (no
/// per-product upsell endpoint exists), so it's not specific to the
/// product being viewed.
class ProductDetailUpsellSection extends StatelessWidget {
  /// Scopes this section's hero tags (e.g. `product_hero_<id>_upsell`) to the
  /// hosting product detail page, so concurrently-mounted pages in the
  /// swipeable pager never collide on the same tag.
  final String heroSuffix;
  final Key? sectionKey;

  const ProductDetailUpsellSection({
    super.key,
    this.heroSuffix = '_upsell',
    this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartRecommendationsCubit, CartRecommendationsState>(
      builder: (context, state) {
        if (state is! CartRecommendationsLoaded) return const SizedBox.shrink();
        final products = state.recommendations.data?.upsell?.products ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        return ProductGridSection(
          sectionKey: sectionKey,
          heroSuffix: heroSuffix,
          title: context.translate(LanguageLabelKeys.upgradeYourOrder),
          products: products,
          total: state.recommendations.data?.upsell?.total ?? products.length,
        );
      },
    );
  }
}
