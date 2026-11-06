import 'dart:math' as math;

import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/home/models/enums/product_block_enums.dart';
import 'package:customer/features/home/utils/responsive_height_helper.dart';
import 'package:customer/features/products/widgets/product_list_item.dart';
import 'package:customer/features/products/models/product_list_scope.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card.dart';
import 'package:customer/features/products/widgets/product_card_details.dart';
import 'package:customer/features/products/widgets/product_card_grid.dart';
import 'package:customer/features/products/widgets/view_more_button.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductBlock extends StatelessWidget {
  final List<ProductDataModel> products;
  final int columns;
  final ProductLayout layout;
  final ProductVariant variant;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final String? textColor;
  final String? imageAspect;
  final String? sectionTitle;
  final int blockPadding;
  final int itemGap;
  final int itemRadius;
  final int limit;
  final ValueChanged<ProductDataModel>? onTap;
  final String blockId;
  final ProductListScope viewMoreScope;
  final ViewMoreTapCallback? onViewMoreTap;
  final List<String>? viewMorePreviewImages;

  const ProductBlock({
    super.key,
    required this.products,
    this.columns = 2,
    this.layout = ProductLayout.grid,
    this.variant = ProductVariant.defaultVariant,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.textColor,
    this.imageAspect,
    this.sectionTitle,
    this.blockPadding = 0,
    this.itemGap = 8,
    this.itemRadius = 0,
    this.limit = 0,
    this.onTap,
    this.blockId = '',
    this.viewMoreScope = const ProductListScope(),
    this.onViewMoreTap,
    this.viewMorePreviewImages,
  });

  bool get _wrapCard =>
      variant == ProductVariant.withColor ||
      variant == ProductVariant.withBackground;

  /// Tallest details block among [displayProducts] at [cardWidth], so every
  /// card in this section can be stretched to match it — content-driven,
  /// not a guessed constant.
  double _maxDetailsHeight(
    BuildContext context,
    List<ProductDataModel> displayProducts,
    double cardWidth,
  ) {
    final textWidth = (cardWidth - 20).clamp(0, cardWidth).toDouble();
    return displayProducts.fold<double>(
      0,
      (max, p) => math.max(
        max,
        ProductCardDetails.estimateHeight(context, p, textWidth),
      ),
    );
  }

  Widget _buildProductContent(
    BuildContext context,
    List<ProductDataModel> displayProducts,
  ) {
    switch (layout) {
      case ProductLayout.horizontal:
        return LayoutBuilder(
          builder: (_, constraints) {
            final isTablet = AppSizes.isTablet(context);
            final gap = itemGap.toDouble() * (isTablet ? 1.75 : 1.0);
            final visibleCount = isTablet ? 4 : 3;
            final itemWidth =
                (constraints.maxWidth - 20 - gap * (visibleCount - 1)) /
                visibleCount;
            final minDetailsHeight = _maxDetailsHeight(
              context,
              displayProducts,
              itemWidth,
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingS,
              ),
              child: Row(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: List.generate(
                  displayProducts.length,
                  (i) => Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: i == displayProducts.length - 1 ? 0 : gap,
                    ),
                    child: SizedBox(
                      width: itemWidth,
                      child: _buildProductCard(
                        context,
                        displayProducts,
                        i,
                        minDetailsHeight: minDetailsHeight,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case ProductLayout.list:
        return Column(
          mainAxisSize: .min,
          children: List.generate(
            displayProducts.length,
            (i) => Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: i == displayProducts.length - 1
                    ? 0
                    : itemGap.toDouble(),
              ),
              child: _buildProductCard(context, displayProducts, i),
            ),
          ),
        );

      case ProductLayout.grid:
        final cols = columns.clamp(1, 10);
        // itemGap comes from the admin/API config tuned for phone card widths —
        // on tablet the same cards are much wider, so the same px gap reads as no gap at all.
        final gap =
            itemGap.toDouble() * (AppSizes.isTablet(context) ? 1.75 : 1.0);
        return LayoutBuilder(
          builder: (_, constraints) {
            final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
            // Section-wide, not per-row — matches horizontal layout so every
            // card in the grid shares one floor and heights stay uniform
            // across rows, not just within a row.
            final minDetailsHeight = _maxDetailsHeight(
              context,
              displayProducts,
              cardWidth,
            );
            return ProductCardGrid(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisCount: cols,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              itemCount: displayProducts.length,
              itemBuilder: (ctx, i, itemCardWidth) => _buildProductCard(
                ctx,
                displayProducts,
                i,
                cardWidth: itemCardWidth,
                minDetailsHeight: minDetailsHeight,
              ),
            );
          },
        );
    }
  }

  Widget _buildProductCard(
    BuildContext context,
    List<ProductDataModel> displayProducts,
    int index, {
    double? cardWidth,
    double? minDetailsHeight,
  }) {
    final product = displayProducts[index];
    final heroSuffix = blockId.isNotEmpty ? '_$blockId' : '';
    final imageUrl = product.images?.coverUrl;
    if (layout == ProductLayout.list) {
      return ProductListItem(
        product: product,
        heroSuffix: heroSuffix,
        siblingProducts: displayProducts,
        index: index,
        onTap: product.id != null
            ? () => AppNavigator.pushNamed(
                context,
                RouteNames.productDetail,
                arguments: ProductDetailArgs(
                  productId: product.id!,
                  imageUrl: imageUrl,
                  heroSuffix: heroSuffix,
                  productList: displayProducts,
                  initialIndex: index,
                ),
              )
            : null,
      );
    }
    return ProductCard(
      product: product,
      heroSuffix: heroSuffix,
      siblingProducts: displayProducts,
      index: index,
      cardWidth: cardWidth,
      cardColor: _wrapCard
          ? (context.isDark ? context.cs.surface : Colors.white)
          : null,
      cardRadius: itemRadius > 0 ? itemRadius.toDouble() : 12,
      minDetailsHeight: minDetailsHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final displayProducts = limit > 0
        ? products.take(limit).toList()
        : products;
    final pad =
        (blockPadding > 0 ? blockPadding.toDouble() : 8.0) *
        (AppSizes.isTablet(context) ? 1.5 : 1.0);
    Widget productContent = _buildProductContent(context, displayProducts);

    final showMeta = variant != ProductVariant.defaultVariant;

    Widget section;
    if (showMeta && sectionTitle?.isNotEmpty == true) {
      final titleColor =
          textColor.toColor() ??
          (context.isDark ? context.cs.onSurface : context.cs.onSurface);
      section = Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Padding(
            padding: layout == ProductLayout.horizontal
                ? const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingS,
                  )
                : EdgeInsets.zero,
            child: AppText(
              sectionTitle!,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          productContent,
        ],
      );
    } else {
      section = productContent;
    }

    // Horizontal layout skips left/right margin here — it already pads inside
    // its scroll view. List rows use the same gap on left/right as between
    // cards, so bordered cards don't touch the screen edge.
    final contentHorizontalPad = switch (layout) {
      ProductLayout.grid => pad,
      ProductLayout.horizontal => ThemeConstants.paddingS,
      ProductLayout.list => itemGap.toDouble(),
    };
    Widget content = Padding(
      padding: switch (layout) {
        ProductLayout.grid => EdgeInsetsDirectional.all(pad),
        ProductLayout.horizontal => EdgeInsetsDirectional.symmetric(
          vertical: pad,
        ),
        ProductLayout.list => EdgeInsetsDirectional.symmetric(
          horizontal: contentHorizontalPad,
          vertical: pad,
        ),
      },
      child: section,
    );

    content = Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        content,
        ViewMoreButton(
          products: products,
          shownCount: limit > 0 ? limit : products.length,
          onTap: () => onViewMoreTap?.call(sectionTitle ?? '', viewMoreScope),
          previewImageUrls: viewMorePreviewImages,
          horizontalMargin: contentHorizontalPad,
        ),
      ],
    );

    if (showMeta &&
        variant == ProductVariant.withBackground &&
        backgroundImageUrl?.isNotEmpty == true) {
      final bgUrl = backgroundImageUrl!;
      final bgContent = content;
      content = LayoutBuilder(
        builder: (ctx, constraints) {
          final ratio = ResponsiveHeightHelper.parseAspectRatio(imageAspect);
          final minHeight = ratio != null
              ? ResponsiveHeightHelper.calculateFromAspect(
                  imageAspect: imageAspect,
                  context: ctx,
                  renderWidth: constraints.maxWidth,
                )
              : 0.0;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              width: double.infinity,
              decoration: AppDecorations.box(
                image: DecorationImage(
                  image: AppNetworkImage.provider(bgUrl),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                ),
              ),
              child: bgContent,
            ),
          );
        },
      );
    } else if (showMeta && variant == ProductVariant.withColor) {
      final bgColor = backgroundColor.toColor();
      if (bgColor != null) {
        content = ColoredBox(color: bgColor, child: content);
      }
    }

    return content;
  }
}
