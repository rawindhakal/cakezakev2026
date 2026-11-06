import 'package:customer/commons/widgets/store_closed_dialog.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/features/products/widgets/delivery_time_icon.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/commons/widgets/cart_button.dart';
import 'package:customer/commons/widgets/notify_me_button.dart';
import 'package:customer/commons/widgets/favorite_button.dart';
import 'package:customer/commons/widgets/star_rating_row.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card_details.dart';
import 'package:customer/features/products/widgets/product_card_pagination_dots.dart';
import 'package:customer/features/products/widgets/product_variant_sheet.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductListItem extends StatefulWidget {
  final ProductDataModel product;
  final VoidCallback? onTap;
  final String heroSuffix;

  /// Sibling products from the list this item is rendered in, so the detail
  /// screen can swipe between them. Pass together with [index].
  final List<ProductDataModel>? siblingProducts;

  /// This item's index within [siblingProducts].
  final int? index;

  const ProductListItem({
    super.key,
    required this.product,
    this.onTap,
    this.heroSuffix = '',
    this.siblingProducts,
    this.index,
  });

  @override
  State<ProductListItem> createState() => _ProductListItemState();
}

class _ProductListItemState extends State<ProductListItem> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _imageFor(int pageIndex) {
    final images = widget.product.images?.preview ?? [];
    if (images.isEmpty) return '';
    return images[pageIndex.clamp(0, images.length - 1)].imageUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isDark = context.isDark;
    final textColor = context.cs.onSurface;
    final subColor = context.cs.onSurfaceVariant;
    final imageBg = context.cs.surfaceContainerHigh;

    // Phone stays on ProductCardDetails' compact scale; tablet switches to
    // its non-compact scale and a bigger image, same as ProductCard does.
    final isTablet = AppSizes.isTablet(context);
    final isCompact = !isTablet;
    final imageSize = context.widthFraction(0.33).clamp(130.0, 200.0);
    // Match product_detail_view's hero memCache dims exactly — the Hero tag
    // shared with this image only reuses the already-decoded bitmap (no
    // placeholder flash mid-flight) when both sides resolve to the same
    // ResizeImage cache key.
    final heroDpr = MediaQuery.devicePixelRatioOf(context);
    final heroMemCacheWidth = (context.screenWidth * heroDpr).round();
    final heroMemCacheHeight = (context.screenHeight * 0.38 * heroDpr).round();
    final nameFontSize = ProductCardDetails.nameFontSize(isCompact);
    final priceFontSize = ProductCardDetails.priceFontSize(isCompact);
    final strikeFontSize = ProductCardDetails.strikeFontSize(isCompact);
    final discountFontSize = ProductCardDetails.discountFontSize(isCompact);
    final starSize = ProductCardDetails.starSize(isCompact);
    final ratingFontSize = ProductCardDetails.ratingFontSize(isCompact);
    final timeFontSize = ProductCardDetails.timeFontSize(isCompact);
    final timeIconSize = ProductCardDetails.timeIconSize(isCompact);

    final variants = product.variants ?? [];
    final images = product.images?.preview ?? [];
    final pageCount = images.isNotEmpty ? images.length : 1;
    final activeV = variants.isNotEmpty ? variants.first : null;
    final isProductOutOfStock =
        activeV?.isOutOfStock == true ||
        (activeV == null && product.isOutOfStock);
    final isStoreClosedQuick = SettingsHiveBox.instance.isStoreClosedQuick;
    final dimOpacity = (isProductOutOfStock || isStoreClosedQuick) ? 0.45 : 1.0;
    final measurement = VariantAttributesFormatter.firstValue(
      activeV?.attributesText,
    );
    final isUnlimited = (product.isUnlimitedStock ?? 0) == 1;
    final stockVal = activeV?.stock ?? product.stock ?? 0;

    final rawPrice = (activeV?.price ?? product.price ?? 0).toDouble();
    final rawDiscounted =
        (activeV?.discountedPrice ?? product.discountedPrice ?? 0).toDouble();
    final hasDiscount = rawDiscounted > 0 && rawDiscounted < rawPrice;
    final displayPrice = hasDiscount ? rawDiscounted : rawPrice;
    final discountPct = hasDiscount && rawPrice > 0
        ? ((rawPrice - rawDiscounted) / rawPrice * 100).round()
        : 0;
    final avgRating = (product.rating ?? 0).toDouble();
    final ratingCount = product.ratingCount ?? 0;
    final variantId =
        activeV?.id?.toString() ??
        product.variantId?.toString() ??
        product.id?.toString() ??
        '';

    return GestureDetector(
      onTap:
          widget.onTap ??
          () {
            if (product.id != null) {
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
          },
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingS,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.box(
          color: context.cs.surface,
          border: Border.all(color: context.cs.outlineVariant),
          borderRadius: AppRadius.r8,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .center,
            children: [
              // Left: details — font scale mirrors ProductCardDetails,
              // keyed off screen width, so list rows and grid cards
              // (phone or tablet) land on the same type scale.
              Expanded(
                child: Opacity(
                  // sold-out opacity logic untouched; store-closed greys the card the same way, independently.
                  opacity: dimOpacity,
                  child: Column(
                    mainAxisAlignment: .start,
                    crossAxisAlignment: .start,
                    children: [
                      Text.rich(
                        ProductCardDetails.nameSpan(
                          product,
                          product.productName ?? '',
                          nameFontSize,
                        ),
                        style: context.tt.labelMedium?.copyWith(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: .ellipsis,
                      ),
                      AppSpacing.h4,
                      Row(
                        children: [
                          AppText(
                            '${product.currency}${displayPrice.formatPrice(product.decimalPoint ?? 2)}',
                            style: context.tt.headlineMedium?.copyWith(
                              fontSize: priceFontSize,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          if (hasDiscount) ...[
                            AppSpacing.w6,
                            Flexible(
                              child: AppText(
                                '${product.currency}${rawPrice.formatPrice(product.decimalPoint ?? 2)}',
                                style: context.tt.labelMedium?.copyWith(
                                  fontSize: strikeFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: subColor,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: subColor,
                                ),
                                maxLines: 1,
                                overflow: .ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasDiscount) ...[
                        AppSpacing.h2,
                        AppText(
                          '$discountPct${AppConstants.percentSymbol}  ${context.translate(LanguageLabelKeys.off).toUpperCase()}',
                          style: context.tt.headlineMedium?.copyWith(
                            fontSize: discountFontSize,
                            fontWeight: FontWeight.w800,
                            color: context.cs.primary,
                          ),
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                      ],
                      if (product.productRating == true &&
                          (avgRating > 0 || ratingCount > 0)) ...[
                        AppSpacing.h4,
                        Row(
                          children: [
                            StarRatingRow(rating: avgRating, size: starSize),
                            AppSpacing.w4,
                            if (ratingCount > 0)
                              AppText(
                                '($ratingCount)',
                                style: context.tt.labelMedium?.copyWith(
                                  fontSize: ratingFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: subColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (measurement.isNotEmpty) ...[
                        AppSpacing.h4,
                        AppText(
                          measurement,
                          style: context.tt.labelSmall?.copyWith(
                            fontSize: isCompact ? 9.5 : 10.5,
                            color: subColor,
                          ),
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                      ],
                      if (ProductCardDetails.showsLeftInStock(
                        product,
                        isOutOfStock: isProductOutOfStock,
                        isUnlimited: isUnlimited,
                        stockVal: stockVal,
                      )) ...[
                        AppSpacing.h4,
                        AppText(
                          '$stockVal ${context.translate(LanguageLabelKeys.leftInStock)}',
                          style: context.tt.displayMedium?.copyWith(
                            fontSize: timeFontSize,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                      ],
                      if (ProductCardDetails.showsDeliveryTime(
                        product,
                        isProductOutOfStock,
                      )) ...[
                        AppSpacing.h4,
                        Row(
                          children: [
                            DeliveryTimeIcon(size: timeIconSize),
                            AppSpacing.w3,
                            Flexible(
                              child: AppText(
                                product.timeToDeliver!,
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: context.tt.displayMedium?.copyWith(
                                  fontSize: timeFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: context.cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              AppSpacing.w12,
              // Right: image with overlays + floating cart button
              BlocBuilder<CartCubit, CartState>(
                builder: (context, cartState) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Image with fav + dots overlay
                      Opacity(
                        opacity: dimOpacity,
                        child: Hero(
                          tag: 'product_hero_${product.id}${widget.heroSuffix}',
                          child: ClipRRect(
                            borderRadius: AppRadius.r8,
                            child: SizedBox(
                              width: imageSize,
                              height: imageSize,
                              child: Stack(
                                children: [
                                  // PageView of images
                                  PageView.builder(
                                    controller: _pageController,
                                    itemCount: pageCount,
                                    onPageChanged: (p) =>
                                        setState(() => _page = p),
                                    itemBuilder: (_, pageIndex) {
                                      final url = _imageFor(pageIndex);
                                      return Container(
                                        color: imageBg,
                                        child: AppNetworkImage(
                                          url: url,
                                          fit: BoxFit.cover,
                                          memCacheWidth: heroMemCacheWidth,
                                          memCacheHeight: heroMemCacheHeight,
                                        ),
                                      );
                                    },
                                  ),
                                  // Page dots
                                  if (pageCount > 1)
                                    PositionedDirectional(
                                      bottom: 7,
                                      start: 5,
                                      child: ProductCardPaginationDots(
                                        pageCount: pageCount,
                                        currentPage: _page,
                                        dotSize: 7.0,
                                        dotHeight: 9.0,
                                        isDark: context.isDark,
                                      ),
                                    ),
                                  // Favorite button
                                  PositionedDirectional(
                                    top: 6,
                                    end: 6,
                                    child: FavoriteButton(
                                      productId: product.id?.toString(),
                                      initialIsFavorite:
                                          product.isFavorite ?? false,
                                      iconSize: 18,
                                    ),
                                  ),
                                  if (isProductOutOfStock)
                                    PositionedDirectional(
                                      top: 0,
                                      start: 0,
                                      child: Container(
                                        decoration: AppDecorations.box(
                                          color: context.cs.inverseSurface,
                                          borderRadius:
                                              const BorderRadiusDirectional.only(
                                                topStart: Radius.circular(8),
                                                bottomEnd: Radius.circular(4),
                                              ),
                                        ),
                                        padding:
                                            const EdgeInsetsDirectional.symmetric(
                                              horizontal:
                                                  ThemeConstants.paddingXS,
                                              vertical:
                                                  ThemeConstants.paddingXS,
                                            ),
                                        child: AppText(
                                          context.translate(
                                            LanguageLabelKeys.soldOut,
                                          ),
                                          style: context.tt.labelSmall
                                              ?.copyWith(
                                                fontSize: 7,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    context.cs.onInverseSurface,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ), // Hero
                      // Floating cart / notify button (bottom-right, overflows)
                      if (isProductOutOfStock)
                        PositionedDirectional(
                          end: -5,
                          bottom: -4,
                          child: NotifyMeButton(
                            key: ValueKey(
                              'notify_list_btn_${product.id}_${activeV?.id}',
                            ),
                            productVariantId: variantId,
                            width: 76,
                            height: 36,
                            fontSize: 12,
                            initiallyNotified: activeV?.isNotified ?? false,
                          ),
                        ),
                      if (!isProductOutOfStock)
                        PositionedDirectional(
                          end: -5,
                          bottom: -4,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Builder(
                                builder: (context) {
                                  // Multi-variant: the button shows the cart
                                  // total across every variant, matching
                                  // ProductCard — a variant added from the
                                  // sheet must reflect here too.
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
                                      'list_btn_${product.id}_${activeV?.id}',
                                    ),
                                    width: 76,
                                    height: 36,
                                    fontSize: 12,
                                    optionsFontSize: 8,
                                    optionCount: variants.length,
                                    initialCount: isMulti
                                        ? multiTotal
                                        : cartState.countFor(variantId),
                                    productId: product.id?.toString() ?? '',
                                    variantId: variantId,
                                    price: displayPrice,
                                    imageUrl: product.images?.coverUrl ?? '',
                                    totalAllowedQuantity:
                                        product.totalAllowedQuantity ?? 0,
                                    // Add-on module: `has_addons` items open
                                    // the variant sheet with its addon list.
                                    hasAddons: product.requiresAddonSheet,
                                    onAddonTap: () => showProductVariantSheet(
                                      context: context,
                                      product: product,
                                      variants: variants,
                                      isDark: isDark,
                                    ),
                                    // CartButton already applies the local
                                    // cart add/remove itself; these hooks
                                    // only handle the multi-variant sheet.
                                    onFirstAdd: () {
                                      if (isMulti) {
                                        showProductVariantSheet(
                                          context: context,
                                          product: product,
                                          variants: variants,
                                          isDark: isDark,
                                        );
                                      }
                                    },
                                    onLastRemove: () {},
                                  );
                                  if (!isStoreClosedQuick) return cartButton;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => showStoreClosedDialog(context),
                                    child: IgnorePointer(child: cartButton),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
