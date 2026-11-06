import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/commons/cubit/location_cubit.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/favourite/cubit/favorite_cubit.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/commons/widgets/grid_list_toggle.dart';
import 'package:customer/commons/widgets/product_listing_view.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () =>
        context.read<FavoriteCubit>().loadFavorites(isLoadMore: true),
  );
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthHiveBox.instance.isLoggedIn) {
        context.read<FavoriteCubit>().loadFavorites();
      }
    });
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  Widget _buildSkeleton(BuildContext context) {
    if (_isGrid) {
      final isTablet = _isTablet(context);
      return ProductGridSkeleton(
        crossAxisCount: isTablet ? 5 : 3,
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        edgePad: 24,
        spacing: ThemeConstants.spaceM * (isTablet ? 1.75 : 1.0),
        mainAxisSpacing: 10 * (isTablet ? 1.75 : 1.0),
      );
    }
    return ListView.separated(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
        vertical: ThemeConstants.paddingM,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => AppSpacing.h10,
      itemBuilder: (context, index) => const ProductListItemSkeleton(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, int>(
      listener: (context, state) {
        if (AuthHiveBox.instance.isLoggedIn) {
          context.read<FavoriteCubit>().loadFavorites();
        }
      },
      child: AppScaffold(
        applyBottomInset: false,
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.favourites),
          showBackButton: true,
          scrollController: _pager.controller,
          actions: [
            GridListToggle(
              isGrid: _isGrid,
              onToggle: (val) {
                setState(() => _isGrid = val);
                if (AuthHiveBox.instance.isLoggedIn) {
                  context.read<FavoriteCubit>().setGridView(val);
                }
                if (_pager.controller.hasClients) {
                  _pager.controller.jumpTo(0);
                }
              },
            ),
            AppSpacing.w8,
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                if (!AuthHiveBox.instance.isLoggedIn) return;
                final cubit = context.read<FavoriteCubit>();
                cubit.loadFavorites();
                await cubit.stream.firstWhere((s) => !s.listLoading);
              },
              child: BlocBuilder<FavoriteCubit, FavoriteState>(
                builder: (context, state) {
                  if (state.listLoading) {
                    return _buildSkeleton(context);
                  }
                  if (state.listError != null && state.products.isEmpty) {
                    return EmptyStateWidget(
                      imagePath: AssetsConstants.noWishlistFound,
                      title: state.listError!,
                      subtitle: context.translate(
                        LanguageLabelKeys.pullToRefresh,
                      ),
                      onRetry: () =>
                          context.read<FavoriteCubit>().loadFavorites(),
                    );
                  }
                  if (state.products.isEmpty) {
                    return EmptyStateWidget(
                      imagePath: AssetsConstants.noWishlistFound,
                      title: context.translate(LanguageLabelKeys.noFavourites),
                      subtitle: context.translate(
                        LanguageLabelKeys.noFavouritesSubtitle,
                      ),
                    );
                  }
                  final cartHasItems = context.select(
                    (CartCubit c) => c.state.totalItems > 0,
                  );
                  return _pager.attach(
                    ProductListingView(
                      products: state.products,
                      isGrid: _isGrid,
                      controller: _pager.controller,
                      isFetchingMore: state.isLoadingMore,
                      padding: EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingM +
                            context.bottomSafePadding +
                            (cartHasItems ? FloatingCartBar.barHeight : 0),
                      ),
                      onFavoriteTap: (product) =>
                          context.read<FavoriteCubit>().toggle(product),
                    ),
                  );
                },
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
      ),
    );
  }
}
