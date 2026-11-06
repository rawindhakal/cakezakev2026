import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/delivery_time_icon.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/commons/widgets/star_rating_row.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductCardDetails extends StatelessWidget {
  final ProductDataModel product;
  final bool isCompact;
  final bool isDark;
  final double displayPrice;
  final double rawPrice;
  final bool hasDiscount;
  final int discountPct;
  final String displayName;
  final double avgRating;
  final int ratingCount;
  final bool isUnlimited;
  final int stockVal;
  final bool isOutOfStock;

  const ProductCardDetails({
    super.key,
    required this.product,
    required this.isCompact,
    required this.isDark,
    required this.displayPrice,
    required this.rawPrice,
    required this.hasDiscount,
    required this.discountPct,
    required this.displayName,
    required this.avgRating,
    required this.ratingCount,
    required this.isUnlimited,
    required this.stockVal,
    required this.isOutOfStock,
  });

  /// Delivery time row — hidden for out-of-stock products.
  static bool showsDeliveryTime(ProductDataModel product, bool isOutOfStock) =>
      !isOutOfStock && product.timeToDeliver?.isNotEmpty == true;

  /// "N left in stock" — only for limited, in-stock products with min alert.
  static bool showsLeftInStock(
    ProductDataModel product, {
    required bool isOutOfStock,
    required bool isUnlimited,
    required int stockVal,
  }) =>
      !isOutOfStock &&
      !isUnlimited &&
      product.isMinAlert == true &&
      stockVal > 0;

  static String _fmtCount(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

  /// Compact threshold — a details block narrower than this (phone grid
  /// cards) uses the smaller font scale; wider blocks (list rows, tablet
  /// grid cards) use the larger one. Shared with [ProductListItem] so both
  /// card styles scale off the same rule.
  static const double compactWidthThreshold = 140;

  static double priceFontSize(bool isCompact) => isCompact ? 14.0 : 17.0;
  static double strikeFontSize(bool isCompact) => isCompact ? 10.0 : 12.0;
  static double discountFontSize(bool isCompact) => isCompact ? 11.0 : 13.0;
  static double nameFontSize(bool isCompact) => isCompact ? 11.5 : 13.5;
  static double starSize(bool isCompact) =>
      isCompact ? ThemeConstants.iconXXS : ThemeConstants.iconXS;
  static double ratingFontSize(bool isCompact) => isCompact ? 9.5 : 11.5;
  static double timeFontSize(bool isCompact) => isCompact ? 9.5 : 11.0;
  static double timeIconSize(bool isCompact) => isCompact ? 10.0 : 12.0;
  static double typeIconSize(double nameFontSize) => nameFontSize + 1;

  /// Product name with the veg/non-veg mark inline before it, so the mark
  /// never blends into the product image. Shared with [ProductListItem].
  static InlineSpan nameSpan(
    ProductDataModel product,
    String name,
    double nameFontSize,
  ) {
    return ProductTypeIcon.nameSpan(
      productType: product.productType,
      name: name,
      size: typeIconSize(nameFontSize),
    );
  }

  /// Estimates this widget's natural height for [product] at [cardWidth],
  /// mirroring the spacing/font sizes used in [build]. Used as a min-height
  /// floor so sibling cards in the same row/section can match the tallest
  /// one without hardcoding a number or clipping any content.
  static double estimateHeight(
    BuildContext context,
    ProductDataModel product,
    double cardWidth,
  ) {
    final isCompact = cardWidth < compactWidthThreshold;
    final variants = product.variants ?? [];
    final activeV = variants.isNotEmpty ? variants.first : null;
    final rawPrice = (activeV?.price ?? product.price ?? 0).toDouble();
    final rawDiscounted =
        (activeV?.discountedPrice ?? product.discountedPrice ?? 0).toDouble();
    final hasDiscount = rawDiscounted > 0 && rawDiscounted < rawPrice;
    final avgRating = (product.rating ?? 0).toDouble();
    final ratingCount = product.ratingCount ?? 0;

    final priceFontSize = ProductCardDetails.priceFontSize(isCompact);
    final discountFontSize = ProductCardDetails.discountFontSize(isCompact);
    final nameFontSize = ProductCardDetails.nameFontSize(isCompact);
    final ratingFontSize = ProductCardDetails.ratingFontSize(isCompact);
    final timeFontSize = ProductCardDetails.timeFontSize(isCompact);

    double height = priceFontSize * 1.35;
    if (hasDiscount) {
      height += (isCompact ? 2 : 3) + discountFontSize * 1.35;
    }
    height += isCompact ? 4 : 5;

    final nameStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: nameFontSize,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ) ??
        TextStyle(
          fontSize: nameFontSize,
          height: 1.3,
          fontWeight: FontWeight.w500,
        );
    final iconSize = typeIconSize(nameFontSize);
    final namePainter = TextPainter(
      text: TextSpan(
        style: nameStyle,
        children: [nameSpan(product, product.name ?? '', nameFontSize)],
      ),
      maxLines: 3,
      textDirection: Directionality.of(context),
    );
    if (ProductTypeIcon.hasIcon(product.productType)) {
      namePainter.setPlaceholderDimensions([
        PlaceholderDimensions(
          size: Size(iconSize + ProductTypeIcon.inlineGap, iconSize),
          alignment: PlaceholderAlignment.middle,
        ),
      ]);
    }
    namePainter.layout(maxWidth: cardWidth > 0 ? cardWidth : double.infinity);
    height += namePainter.height;

    final showRating =
        product.productRating == true && (avgRating > 0 || ratingCount > 0);
    if (showRating) {
      height += (isCompact ? 3 : 5) + ratingFontSize * 1.5;
    }

    final isOutOfStock =
        activeV?.isOutOfStock == true ||
        (activeV == null && product.isOutOfStock);
    final showDelivery =
        showsDeliveryTime(product, isOutOfStock) ||
        showsLeftInStock(
          product,
          isOutOfStock: isOutOfStock,
          isUnlimited: (product.isUnlimitedStock ?? 0) == 1,
          stockVal: activeV?.stock ?? product.stock ?? 0,
        );
    if (showDelivery) {
      height += (isCompact ? 3 : 4) + timeFontSize * 1.5;
    }

    // Safety buffer — text rendering (line-height, font metrics) can exceed
    // this estimate by a few px; never let the floor undershoot real content.
    return height + 6;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = context.cs.onSurface;
    final subColor = context.cs.onSurfaceVariant;
    final mutedColor = context.cs.onSurfaceVariant;
    final decimalPoint = product.decimalPoint ?? 2;

    final priceFontSize = ProductCardDetails.priceFontSize(isCompact);
    final strikeFontSize = ProductCardDetails.strikeFontSize(isCompact);
    final discountFontSize = ProductCardDetails.discountFontSize(isCompact);
    final nameFontSize = ProductCardDetails.nameFontSize(isCompact);
    final starSize = ProductCardDetails.starSize(isCompact);
    final ratingFontSize = ProductCardDetails.ratingFontSize(isCompact);
    final timeFontSize = ProductCardDetails.timeFontSize(isCompact);
    final timeIconSize = ProductCardDetails.timeIconSize(isCompact);
    final showTime = showsDeliveryTime(product, isOutOfStock);
    final showLeft = showsLeftInStock(
      product,
      isOutOfStock: isOutOfStock,
      isUnlimited: isUnlimited,
      stockVal: stockVal,
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: isCompact ? ThemeConstants.paddingXS : ThemeConstants.paddingXS,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: .baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AppText(
                '${product.currency}${displayPrice.formatPrice(decimalPoint)}',
                style: context.tt.headlineMedium?.copyWith(
                  fontSize: priceFontSize,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              if (hasDiscount) ...[
                SizedBox(width: isCompact ? 4 : 6),
                Flexible(
                  child: AppText(
                    '${product.currency}${rawPrice.formatPrice(decimalPoint)}',
                    style: context.tt.labelMedium?.copyWith(
                      fontSize: strikeFontSize,
                      color: subColor,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (hasDiscount) ...[
            SizedBox(height: isCompact ? 2 : 3),
            Row(
              children: [
                AppText(
                  '$discountPct${AppConstants.percentSymbol} ${context.translate(LanguageLabelKeys.off).toUpperCase()}',
                  style: context.tt.headlineMedium?.copyWith(
                    fontSize: discountFontSize,
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSecondaryContainer,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                SizedBox(width: isCompact ? 6 : 8),
                Expanded(
                  child: _DashedLine(
                    color: context.cs.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isCompact ? 4 : 5),
          Text.rich(
            ProductCardDetails.nameSpan(product, displayName, nameFontSize),
            style: context.tt.labelMedium?.copyWith(
              fontSize: nameFontSize,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: .ellipsis,
          ),
          if (product.productRating == true &&
              (avgRating > 0 || ratingCount > 0)) ...[
            SizedBox(height: isCompact ? 3 : 5),
            Row(
              children: [
                StarRatingRow(rating: avgRating, size: starSize),
                SizedBox(width: isCompact ? 2 : 4),
                if (ratingCount > 0)
                  AppText(
                    '(${_fmtCount(ratingCount)})',
                    style: context.tt.labelMedium?.copyWith(
                      fontSize: ratingFontSize,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
              ],
            ),
          ],
          if (showTime || showLeft)
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: isCompact
                    ? ThemeConstants.paddingXS
                    : ThemeConstants.paddingXS,
              ),
              child: Row(
                children: [
                  if (showTime) ...[
                    DeliveryTimeIcon(size: timeIconSize),
                    SizedBox(width: isCompact ? 2 : 3),
                    Flexible(
                      child: AppText(
                        product.timeToDeliver!,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.tt.displayMedium?.copyWith(
                          fontSize: timeFontSize,
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (showLeft && showTime) SizedBox(width: isCompact ? 6 : 8),
                  if (showLeft) ...[
                    RotatedBox(
                      quarterTurns: -2,
                      child: AppSvgIcon(
                        AssetsConstants.fewLeftIcon,
                        size: ThemeConstants.iconXXS,
                        color: mutedColor,
                        bakeTint: true,
                      ),
                    ),
                    AppSpacing.w4,
                    Flexible(
                      child: AppText(
                        '$stockVal ${context.translate(LanguageLabelKeys.leftInStock)}',
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.tt.displayMedium?.copyWith(
                          fontSize: timeFontSize,
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  final Color color;

  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashedLinePainter(color: color),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  static const double dashWidth = 4;
  static const double dashGap = 4;

  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
