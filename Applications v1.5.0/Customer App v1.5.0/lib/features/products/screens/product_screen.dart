import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/category/widgets/sub_category_filter_bar.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/commons/widgets/grid_list_toggle.dart';
import 'package:customer/commons/widgets/product_listing_view.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

typedef _ProductState = PaginationState<ProductDataModel>;
typedef _ProductLoaded = PaginationLoaded<ProductDataModel>;
typedef _ProductError = PaginationError<ProductDataModel>;
typedef _ProductLoading = PaginationLoading<ProductDataModel>;
typedef _ProductInitial = PaginationInitial<ProductDataModel>;

class ProductScreen extends StatefulWidget {
  final String title;

  /// Pre-fetched list (recently-visited/similar-products already hold the
  /// full set) — renders statically with no API call when provided.
  final List<ProductDataModel>? products;
  final String? categoryId;
  final String? dataSource;
  final String? manualProductIds;
  final String? brandId;

  /// Home row scope (View More): the row's brand_ids and filter_mode, sent to
  /// both the product list and the filters call so they match the row.
  final String? scopeBrandIds;
  final String? filterMode;

  /// Home banner with redirect_type "products": the server's query map,
  /// used as-is for the initial list/filters/sort state. Null otherwise.
  final Map<String, String>? redirectParams;

  const ProductScreen({
    super.key,
    required this.title,
    this.products,
    this.categoryId,
    this.dataSource,
    this.manualProductIds,
    this.brandId,
    this.scopeBrandIds,
    this.filterMode,
    this.redirectParams,
  });

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<ProductCubit>().loadMore(),
  );
  bool _isGrid = true;

  // Kept so the filter/sort/toggle bar stays visible while a grid<->list
  // switch (or sort/filter change) is re-fetching — otherwise the whole
  // row would vanish until the new page loads.
  _ProductLoaded? _lastLoaded;

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  int _crossAxisCount(BuildContext context) => _isTablet(context) ? 5 : 3;

  bool get _isStatic => widget.products != null;

  FilterCubit? _filterCubit;

  void _onToggleGrid(bool val) {
    setState(() => _isGrid = val);
    if (!_isStatic) {
      context.read<ProductCubit>().setGridView(val);
      if (_pager.controller.hasClients) {
        _pager.controller.jumpTo(0);
      }
    }
  }

  void _loadProducts() => context.read<ProductCubit>().loadProducts(
    categoryId: widget.categoryId ?? '',
    dataSource: widget.dataSource,
    manualProductIds: widget.manualProductIds,
    brandId: widget.brandId,
    scopeBrandIds: widget.scopeBrandIds,
    filterMode: widget.filterMode,
    redirectParams: widget.redirectParams,
    isGrid: _isGrid,
  );

  @override
  void initState() {
    super.initState();
    if (!_isStatic) {
      _loadProducts();
      final redirectParams = widget.redirectParams;
      if (redirectParams != null) {
        // Same map as the listing (minus paging/sort) so the sheet only
        // offers brands/attributes/price range inside the banner's scope.
        final banner = ProductFilter.fromRedirectParams(redirectParams);
        _filterCubit = FilterCubit()
          ..loadFilters(
            categoryId: banner.categoryId,
            brandIds: banner.brandIds.isEmpty
                ? null
                : banner.brandIds.join(','),
            attributeValueIds: banner.attributeValueIds.isEmpty
                ? null
                : banner.attributeValueIds.join(','),
            minPrice: banner.minPrice,
            maxPrice: banner.maxPrice,
            minDiscountPercent: banner.minDiscountPercent,
            maxDiscountPercent: banner.maxDiscountPercent,
          );
      } else {
        _filterCubit = FilterCubit()
          ..loadFilters(
            categoryId: widget.categoryId,
            dataSource: widget.dataSource,
            manualProductIds: widget.manualProductIds,
            brandIds: widget.scopeBrandIds,
            filterMode: widget.filterMode,
          );
      }
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    _filterCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      appBar: CustomAppBar(
        title: widget.title,
        scrollController: _pager.controller,
        actions: _isStatic
            ? [
                GridListToggle(isGrid: _isGrid, onToggle: _onToggleGrid),
                AppSpacing.w12,
              ]
            : null,
      ),
      body: Stack(
        children: [
          _isStatic
              ? _buildStaticGrid(widget.products!)
              : BlocProvider.value(
                  value: _filterCubit!,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final cubit = context.read<ProductCubit>();
                      cubit.refresh();
                      await cubit.stream.firstWhere(
                        (s) => s is! _ProductLoading,
                      );
                    },
                    child: _buildLiveGrid(),
                  ),
                ),
          Positioned(
            bottom: context.bottomSafePadding,
            left: 0,
            right: 0,
            child: FloatingCartBar(
              onViewCart: () =>
                  AppNavigator.pushNamed(context, RouteNames.checkout),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticGrid(List<ProductDataModel> products) {
    if (products.isEmpty) {
      return Center(
        child: AppText(context.translate(LanguageLabelKeys.noProductsFound)),
      );
    }
    return ProductListingView(
      products: products,
      isGrid: _isGrid,
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL + context.bottomSafePadding,
      ),
    );
  }

  Widget _buildLiveGrid() {
    return BlocConsumer<ProductCubit, _ProductState>(
      listener: (context, state) {
        if (state is _ProductLoaded) _lastLoaded = state;
      },
      builder: (context, state) {
        if (state is _ProductLoading || state is _ProductInitial) {
          final skeleton = _isGrid
              ? ProductGridSkeleton(
                  crossAxisCount: _crossAxisCount(context),
                  edgePad: 32,
                  spacing:
                      ThemeConstants.spaceM * (_isTablet(context) ? 1.75 : 1.0),
                  mainAxisSpacing: 16 * (_isTablet(context) ? 1.75 : 1.0),
                )
              : const ProductListSkeleton();
          final lastLoaded = _lastLoaded;
          if (lastLoaded == null) return skeleton;
          return Column(
            children: [
              SubCategoryFilterBar(
                state: lastLoaded,
                isGrid: _isGrid,
                onToggleGrid: _onToggleGrid,
              ),
              Expanded(child: skeleton),
            ],
          );
        }
        if (state is _ProductError) {
          return EmptyStateWidget(
            imagePath: AssetsConstants.noSearchFound,
            title: state.message,
            subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
            onRetry: _loadProducts,
          );
        }
        if (state is _ProductLoaded) {
          return Column(
            children: [
              SubCategoryFilterBar(
                state: state,
                isGrid: _isGrid,
                onToggleGrid: _onToggleGrid,
              ),
              Expanded(
                child: state.data.isEmpty
                    ? EmptyStateWidget(
                        imagePath: AssetsConstants.noSearchFound,
                        title: context.translate(
                          LanguageLabelKeys.noProductsFound,
                        ),
                        subtitle: context.translate(
                          LanguageLabelKeys.noProductsFoundSubtitle,
                        ),
                      )
                    : _pager.attach(
                        ProductListingView(
                          products: state.data,
                          isGrid: _isGrid,
                          controller: _pager.controller,
                          isFetchingMore: state.isFetchingMore,
                          padding: EdgeInsetsDirectional.fromSTEB(
                            ThemeConstants.paddingL,
                            ThemeConstants.paddingL,
                            ThemeConstants.paddingL,
                            ThemeConstants.paddingL +
                                context.bottomSafePadding +
                                (context.select(
                                      (CartCubit c) => c.state.totalItems > 0,
                                    )
                                    ? FloatingCartBar.barHeight
                                    : 0),
                          ),
                        ),
                      ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
