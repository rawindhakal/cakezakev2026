import 'package:customer/commons/widgets/app_bouncing.dart';
import 'package:customer/commons/widgets/store_closed_dialog.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/commons/widgets/cart_button.dart';
import 'package:customer/commons/widgets/notify_me_button.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card_details.dart';
import 'package:customer/features/products/widgets/product_card_media.dart';
import 'package:customer/features/products/widgets/product_variant_sheet.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductCard extends StatefulWidget {
  final ProductDataModel product;
  final VoidCallback? onAddTap;
  final void Function(Variants variant)? onAddVariant;
  final VoidCallback? onRemoveTap;
  final void Function(Variants variant)? onRemoveVariant;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onCardTap;

  /// Extra suffix to make hero tag unique when same product appears in multiple sections.
  final String heroSuffix;

  /// Sibling products from the list this card is rendered in, so the detail
  /// screen can swipe between them. Pass together with [index].
  final List<ProductDataModel>? siblingProducts;

  /// This card's index within [siblingProducts].
  final int? index;

  /// Pre-computed cell width, e.g. from [ProductCardGrid] which already knows
  /// the grid's available width. When set, skips the internal LayoutBuilder —
  /// needed because callers may wrap this card in IntrinsicHeight (to equalize
  /// row heights), and LayoutBuilder cannot report intrinsic dimensions.
  final double? cardWidth;

  /// When set, wraps image + details in one unified themed card (white in
  /// light mode, surface color in dark mode) with [cardRadius] corners —
  /// used by the home builder product section for with_color/with_background
  /// variants. Null keeps the default flush look used everywhere else.
  final Color? cardColor;
  final double cardRadius;

  /// Floor for the details block's height, computed by the caller from the
  /// tallest sibling's actual content (see [ProductCardDetails.estimateHeight])
  /// so short-content cards visually match tall ones in the same row without
  /// clipping anything. Only meaningful alongside [cardColor].
  final double? minDetailsHeight;

  const ProductCard({
    super.key,
    required this.product,
    this.onAddTap,
    this.onAddVariant,
    this.onRemoveTap,
    this.onRemoveVariant,
    this.onFavoriteTap,
    this.onCardTap,
    this.heroSuffix = '',
    this.siblingProducts,
    this.index,
    this.cardWidth,
    this.cardColor,
    this.cardRadius = 12,
    this.minDetailsHeight,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late final PageController _pageController;
  int _page = 0;

  void _handleAddTap(List<Variants> variants) {
    if (variants.length <= 1) {
      if (variants.isNotEmpty && widget.onAddVariant != null) {
        widget.onAddVariant!(variants.first);
      } else {
        widget.onAddTap?.call();
      }
      return;
    }
    showProductVariantSheet(
      context: context,
      product: widget.product,
      variants: variants,
      isDark: context.isDark,
      onFirstAdd: (v) => widget.onAddVariant?.call(v),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isDark = context.isDark;

    final variants = product.variants ?? [];
    final activeV = variants.isNotEmpty ? variants.first : null;

    final displayName = product.productName ?? '';
    final isProductOutOfStock =
        activeV?.isOutOfStock == true ||
        (activeV == null && product.isOutOfStock);
    final isStoreClosedQuick = SettingsHiveBox.instance.isStoreClosedQuick;

    final rawPrice = (activeV?.price ?? product.price ?? 0).toDouble();
    final rawDiscounted =
        (activeV?.discountedPrice ?? product.discountedPrice ?? 0).toDouble();
    final hasDiscount = rawDiscounted > 0 && rawDiscounted < rawPrice;
    final displayPrice = hasDiscount ? rawDiscounted : rawPrice;
    final discountPct = hasDiscount && rawPrice > 0
        ? ((rawPrice - rawDiscounted) / rawPrice * 100).round()
        : 0;

    // attributesText is "Color: Red, Size: M" — show just the first value (e.g. "Red").
    final measurement = VariantAttributesFormatter.firstValue(
      activeV?.attributesText,
    );
    final avgRating = (product.rating ?? 0).toDouble();
    final ratingCount = product.ratingCount ?? 0;
    final isUnlimited = (product.isUnlimitedStock ?? 0) == 1;
    final stockVal = activeV?.stock ?? product.stock ?? 0;
    final variantId =
        activeV?.id?.toString() ??
        product.variantId?.toString() ??
        product.id?.toString() ??
        '';

    final isCardWrapped = widget.cardColor != null;

    Widget buildCard(double cardWidth) {
      final isCompact = cardWidth < 140;
      final imageHeight = (cardWidth * 1.3).clamp(140.0, 280.0);
      final addBtnW = isCompact ? 58.0 : 76.0;
      final addBtnH = isCompact ? 36.0 : 45.0;
      final addFontSize = isCompact ? 10.0 : 13.0;
      final optionsFontSize = isCompact ? 7.0 : 8.0;

      void handleCardTap() {
        if (widget.onCardTap != null) {
          widget.onCardTap!();
        } else if (product.id != null) {
          AppNavigator.pushNamed(
            context,
            RouteNames.productDetail,
            arguments: ProductDetailArgs(
              productId: product.id!,
              imageUrl: product.images?.coverUrl,
              heroSuffix: widget.heroSuffix,
              productList: widget.siblingProducts,
              initialIndex: widget.index ?? 0,
            ),
          );
        }
      }

      final dimOpacity = (isProductOutOfStock || isStoreClosedQuick)
          ? 0.65
          : 1.0;

      final cardChild = Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Padding(
            padding: isCardWrapped
                ? const EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS,
                    0,
                  )
                : EdgeInsets.zero,
            child: SizedBox(
              height: imageHeight,
              child: Hero(
                tag: 'product_hero_${product.id}${widget.heroSuffix}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          // sold-out opacity logic untouched; store-closed greys the card the same way, independently.
                          opacity: dimOpacity,
                          child: ProductCardMedia(
                            product: product,
                            pageController: _pageController,
                            currentPage: _page,
                            onPageChanged: (p) => setState(() => _page = p),
                            measurement: measurement,
                            isOutOfStock: isProductOutOfStock,
                            isCompact: isCompact,
                            isDark: isDark,
                            onFavoriteTap: widget.onFavoriteTap,
                            embedded: isCardWrapped,
                            topRadius: widget.cardRadius,
                            // Button overhangs the media end by 5px.
                            measurementEndInset: addBtnW - 5 + 4,
                          ),
                        ),
                      ),
                      // Notify button stays at full opacity even though
                      // the sold-out image beneath it is dimmed.
                      if (isProductOutOfStock)
                        PositionedDirectional(
                          end: -5,
                          bottom: -4,
                          child: NotifyMeButton(
                            key: ValueKey(
                              'notify_btn_${product.id}_${activeV?.id}',
                            ),
                            productVariantId: variantId,
                            width: addBtnW,
                            height: addBtnH,
                            fontSize: addFontSize,
                            initiallyNotified: activeV?.isNotified ?? false,
                          ),
                        ),
                      if (!isProductOutOfStock)
                        PositionedDirectional(
                          end: -5,
                          bottom: -4,
                          child: BlocBuilder<CartCubit, CartState>(
                            builder: (context, cartState) {
                              final isMulti = variants.length > 1;
                              final multiTotal = isMulti
                                  ? variants.fold<int>(
                                      0,
                                      (s, v) =>
                                          s +
                                          cartState.countFor(
                                            v.id?.toString() ?? '',
                                          ),
                                    )
                                  : 0;
                              final cartButton = CartButton(
                                key: ValueKey(
                                  'cart_btn_${product.id}_${activeV?.id}',
                                ),
                                width: addBtnW,
                                height: addBtnH,
                                fontSize: addFontSize,
                                optionsFontSize: optionsFontSize,
                                optionCount: variants.length,
                                initialCount: isMulti
                                    ? multiTotal
                                    : cartState.countFor(variantId),
                                productId: product.id?.toString() ?? '',
                                variantId: variantId,
                                price: hasDiscount ? rawDiscounted : rawPrice,
                                imageUrl: product.images?.coverUrl ?? '',
                                totalAllowedQuantity:
                                    product.totalAllowedQuantity ?? 0,
                                // Add-on module: `has_addons` cards open the
                                // variant sheet, whose addon list sits under
                                // the variants, instead of adding directly.
                                hasAddons: product.requiresAddonSheet,
                                onAddonTap: () => showProductVariantSheet(
                                  context: context,
                                  product: product,
                                  variants: variants,
                                  isDark: isDark,
                                ),
                                onFirstAdd: () => _handleAddTap(variants),
                                onLastRemove: () {
                                  if (variants.length == 1 &&
                                      variants.isNotEmpty) {
                                    widget.onRemoveVariant?.call(
                                      variants.first,
                                    );
                                  } else {
                                    widget.onRemoveTap?.call();
                                  }
                                },
                              );
                              if (!isStoreClosedQuick) return cartButton;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => showStoreClosedDialog(context),
                                child: IgnorePointer(child: cartButton),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: isCardWrapped
                ? const EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS,
                  )
                : EdgeInsets.zero,
            child: Opacity(
              opacity: dimOpacity,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.minDetailsHeight ?? 0,
                ),
                child: ProductCardDetails(
                  product: product,
                  isCompact: isCompact,
                  isDark: isDark,
                  displayPrice: displayPrice,
                  rawPrice: rawPrice,
                  hasDiscount: hasDiscount,
                  discountPct: discountPct,
                  displayName: displayName,
                  avgRating: avgRating,
                  ratingCount: ratingCount,
                  isUnlimited: isUnlimited,
                  stockVal: stockVal,
                  isOutOfStock: isProductOutOfStock,
                ),
              ),
            ),
          ),
        ],
      );

      final Widget decoratedCard = isCardWrapped
          ? Container(
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(widget.cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: context.theme.shadowColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: cardChild,
            )
          : cardChild;

      return AppBouncing(onTap: handleCardTap, child: decoratedCard);
    }

    if (widget.cardWidth != null) return buildCard(widget.cardWidth!);
    return LayoutBuilder(
      builder: (context, constraints) => buildCard(constraints.maxWidth),
    );
  }
}
