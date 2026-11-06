import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/favorite_button.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card_pagination_dots.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

const double _measureStripLineFactor = 1.4;

class ProductCardMedia extends StatelessWidget {
  final ProductDataModel product;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final String measurement;
  final bool isOutOfStock;
  final bool isCompact;
  final bool isDark;
  final VoidCallback? onFavoriteTap;

  /// When true, media renders flush (no own background/border/shadow) so it
  /// sits inside an outer unified card supplied by the caller.
  final bool embedded;

  /// Top corner radius to clip the image to. Ignored when [embedded] is false.
  final double topRadius;

  /// Space kept clear at the end of the attribute strip so the label never
  /// runs under the overlaid ADD / Notify button.
  final double measurementEndInset;

  const ProductCardMedia({
    super.key,
    required this.product,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
    required this.measurement,
    required this.isOutOfStock,
    required this.isCompact,
    required this.isDark,
    this.onFavoriteTap,
    this.embedded = false,
    this.topRadius = 10,
    this.measurementEndInset = 0,
  });

  String _imageFor(int pageIndex, List<Images> images) {
    if (images.isEmpty) return '';
    return images[pageIndex.clamp(0, images.length - 1)].imageUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cs.surfaceContainer;
    final attributeBg = context.cs.surfaceContainerHigh;
    final border = context.cs.outline;
    final textColor = context.cs.onSurface;
    final images = product.images?.preview ?? [];
    final pageCount = images.isNotEmpty ? images.length : 1;
    final favIconSize = isCompact ? 16.0 : 20.0;
    final dotSize = isCompact ? 6.0 : 7.0;
    final dotH = isCompact ? 8.0 : 9.0;
    final cardPadH = isCompact ? 7.0 : 10.0;
    final cardPadV = isCompact ? 6.0 : 8.0;
    final measureFontSize = isCompact ? 10.0 : 13.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Container(
      decoration: embedded
          ? null
          : AppDecorations.outlinedCard(
              color: cardBg,
              borderColor: border,
              borderRadius: 10,
              boxShadow: [
                BoxShadow(
                  color: context.theme.shadowColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: embedded
                      ? BorderRadius.vertical(top: Radius.circular(topRadius))
                      : const BorderRadius.vertical(top: Radius.circular(10)),
                  child: SizedBox(
                    width: double.infinity,
                    // Decode at the card's own size, not screen size — grid rows
                    // hold several cards, and full-screen bitmaps per card made
                    // scrolling decode/raster heavy.
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final memW = (box.maxWidth * dpr).round();
                        final memH = box.maxHeight.isFinite
                            ? (box.maxHeight * dpr).round()
                            : null;
                        return PageView.builder(
                          controller: pageController,
                          itemCount: pageCount,
                          onPageChanged: onPageChanged,
                          itemBuilder: (context, pageIndex) {
                            return Container(
                              color: cardBg,
                              child: AppNetworkImage(
                                url: _imageFor(pageIndex, images),
                                fit: BoxFit.cover,
                                memCacheWidth: memW,
                                memCacheHeight: memH,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (pageCount > 1)
                  PositionedDirectional(
                    bottom: 7,
                    start: 5,
                    child: ProductCardPaginationDots(
                      pageCount: pageCount,
                      currentPage: currentPage,
                      dotSize: dotSize,
                      dotHeight: dotH,
                      isDark: isDark,
                    ),
                  ),
                PositionedDirectional(
                  top: isCompact ? 6 : 10,
                  end: isCompact ? 6 : 10,
                  child: FavoriteButton(
                    productId: product.id?.toString(),
                    initialIsFavorite: product.isFavorite ?? false,
                    iconSize: favIconSize,
                    onTap: onFavoriteTap,
                  ),
                ),
                if (isOutOfStock)
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    child: Container(
                      decoration: AppDecorations.box(
                        color: context.cs.inverseSurface,
                        borderRadius: const BorderRadiusDirectional.only(
                          topStart: Radius.circular(10),
                          bottomEnd: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.theme.shadowColor.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingS,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      child: AppText(
                        context.translate(LanguageLabelKeys.soldOut),
                        style: context.tt.labelSmall?.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: context.cs.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            // Fixed at single-line height so a long label shrinks into the
            // strip instead of growing it (which shrank the image above).
            height:
                measureFontSize * _measureStripLineFactor + cardPadV * 2 + 0.8,
            alignment: AlignmentDirectional.centerStart,
            decoration: AppDecorations.box(
              color: attributeBg,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(embedded ? topRadius : 10),
              ),
              border: Border(top: BorderSide(color: border, width: 0.8)),
            ),
            padding: EdgeInsetsDirectional.fromSTEB(
              cardPadH,
              cardPadV,
              measurementEndInset > cardPadH ? measurementEndInset : cardPadH,
              cardPadV,
            ),
            child: AutoSizeText(
              measurement.isNotEmpty ? measurement : '—',
              style: context.tt.displayMedium?.copyWith(
                fontSize: measureFontSize,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.15,
              ),
              maxLines: 2,
              minFontSize: 6,
              stepGranularity: 0.5,
              wrapWords: false,
              overflow: .ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
