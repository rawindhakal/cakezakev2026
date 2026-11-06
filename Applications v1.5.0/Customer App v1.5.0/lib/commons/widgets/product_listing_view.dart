import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card.dart';
import 'package:customer/features/products/widgets/product_card_grid.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:customer/features/products/widgets/product_list_item.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Shared grid/list rendering for a plain product-listing screen (product
/// list, search results, ...) driven by a [GridListToggle]. Handles the
/// cross-axis-count/spacing calc and the standard product-detail navigation
/// for both layouts, so screens only own their data-fetch/cubit wiring.
class ProductListingView extends StatelessWidget {
  final List<ProductDataModel> products;
  final bool isGrid;
  final ScrollController? controller;
  final bool isFetchingMore;
  final EdgeInsetsDirectional padding;

  /// Pass true (with [physics] set to [NeverScrollableScrollPhysics]) when
  /// this is nested inside an outer scrollable — e.g. a full-page
  /// SingleChildScrollView that also scrolls a header above the list.
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Grid-mode only — [ProductListItem] doesn't expose a favorite-tap
  /// override, so list mode always falls back to the button's own default.
  /// When omitted, grid falls back to the same default too.
  final ValueChanged<ProductDataModel>? onFavoriteTap;

  /// List-mode load-more placeholder override. Defaults to
  /// [ProductListItemSkeleton]; pass this to reuse a screen's existing
  /// loading indicator instead.
  final WidgetBuilder? listLoadingMoreBuilder;

  /// Fired right before navigating to product detail, in both layouts —
  /// e.g. to record a result tap as an implicit recent-search save.
  final ValueChanged<ProductDataModel>? onProductTap;

  const ProductListingView({
    super.key,
    required this.products,
    required this.isGrid,
    this.controller,
    this.isFetchingMore = false,
    this.padding = const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
    this.onFavoriteTap,
    this.listLoadingMoreBuilder,
    this.onProductTap,
    this.shrinkWrap = false,
    this.physics,
  });

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  int _crossAxisCount(BuildContext context) => _isTablet(context) ? 5 : 3;

  @override
  Widget build(BuildContext context) {
    return isGrid ? _buildGrid(context) : _buildList(context);
  }

  Widget _buildGrid(BuildContext context) {
    final spacing = 10 * (_isTablet(context) ? 1.75 : 1.0);
    return ProductCardGrid(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: padding,
      crossAxisCount: _crossAxisCount(context),
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      itemCount:
          products.length + (isFetchingMore ? _crossAxisCount(context) : 0),
      itemBuilder: (context, i, cardWidth) {
        if (i >= products.length) {
          return const ProductCardSkeleton();
        }
        final product = products[i];
        return ProductCard(
          product: product,
          siblingProducts: products,
          index: i,
          cardWidth: cardWidth,
          onFavoriteTap: onFavoriteTap == null
              ? null
              : () => onFavoriteTap!(product),
          onCardTap: onProductTap == null || product.id == null
              ? null
              : () {
                  onProductTap!(product);
                  AppNavigator.pushNamed(
                    context,
                    RouteNames.productDetail,
                    arguments: ProductDetailArgs(
                      productId: product.id!,
                      imageUrl: product.images?.coverUrl,
                      heroSuffix: '',
                      productList: products,
                      initialIndex: i,
                    ),
                  );
                },
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: products.length + (isFetchingMore ? 1 : 0),
      separatorBuilder: (_, _) => AppSpacing.h10,
      itemBuilder: (context, i) {
        if (i >= products.length) {
          return listLoadingMoreBuilder?.call(context) ??
              const ProductListItemSkeleton();
        }
        final product = products[i];
        return ProductListItem(
          product: product,
          heroSuffix: '_$i',
          siblingProducts: products,
          index: i,
          onTap: product.id == null
              ? null
              : () {
                  onProductTap?.call(product);
                  AppNavigator.pushNamed(
                    context,
                    RouteNames.productDetail,
                    arguments: ProductDetailArgs(
                      productId: product.id!,
                      imageUrl: product.images?.coverUrl,
                      heroSuffix: '_$i',
                      productList: products,
                      initialIndex: i,
                    ),
                  );
                },
        );
      },
    );
  }
}
