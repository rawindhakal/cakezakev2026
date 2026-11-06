import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:customer/features/products/widgets/product_card.dart';
import 'package:customer/features/products/widgets/product_card_grid.dart';
import 'package:customer/features/products/widgets/view_more_button.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';

/// Titled card holding a non-scrolling grid of up to [maxItems] products with a
/// "view more" button. Shared by the product detail page's upsell, similar and
/// recently-visited sections, which differ only in their data source.
class ProductGridSection extends StatelessWidget {
  final String title;
  final List<ProductDataModel> products;

  /// Total number of products available; the view-more button shows when this
  /// exceeds [maxItems].
  final int total;

  /// Scopes the cards' hero tags to the hosting product detail page, so
  /// concurrently-mounted pages in the swipeable pager never collide.
  final String heroSuffix;
  final Key? sectionKey;
  final double mainAxisSpacing;

  const ProductGridSection({
    super.key,
    required this.title,
    required this.products,
    required this.total,
    required this.heroSuffix,
    this.sectionKey,
    this.mainAxisSpacing = 10,
  });

  static const int maxItems = 6;

  @override
  Widget build(BuildContext context) {
    final displayProducts = products.take(maxItems).toList();
    final hasMore = total > maxItems;

    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final crossAxisCount = isTablet ? 5 : 3;
    final spacingScale = isTablet ? 1.75 : 1.0;

    return Container(
      key: sectionKey,
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingL,
        vertical: ThemeConstants.paddingS,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingM,
              ThemeConstants.paddingL,
              ThemeConstants.paddingM,
              ThemeConstants.paddingM,
            ),
            child: AppText(
              title,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.cs.onSurface,
              ),
            ),
          ),
          ProductCardGrid(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingM,
              0,
              ThemeConstants.paddingM,
              ThemeConstants.paddingS,
            ),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10 * spacingScale,
            mainAxisSpacing: mainAxisSpacing * spacingScale,
            itemCount: displayProducts.length,
            itemBuilder: (context, i, cardWidth) => ProductCard(
              product: displayProducts[i],
              heroSuffix: heroSuffix,
              siblingProducts: displayProducts,
              index: i,
              cardWidth: cardWidth,
            ),
          ),
          if (hasMore)
            ViewMoreButton(
              products: products,
              onTap: () => AppNavigator.push(
                context,
                ProductScreen(title: title, products: products),
              ),
            ),
        ],
      ),
    );
  }
}
