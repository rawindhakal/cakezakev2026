import 'dart:math' as math;
import 'package:customer/features/products/widgets/addon_section.dart';
import 'package:customer/commons/animations/peek_expand_dismiss_controller.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/cubit/cart_recommendations_cubit.dart';
import 'package:customer/features/products/cubit/add_recently_visited_product_cubit.dart';
import 'package:customer/features/products/cubit/product_detail_cubit.dart';
import 'package:customer/features/products/cubit/rating_images_cubit.dart';
import 'package:customer/features/products/cubit/ratings_list_cubit.dart';
import 'package:customer/features/products/cubit/recently_visited_cubit.dart';
import 'package:customer/features/products/cubit/similar_product_cubit.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/products/widgets/product_detail_bottom_bar.dart';
import 'package:customer/features/products/widgets/product_detail_view.dart';
import 'package:customer/utils/ensure_visible_and_flash.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final String? initialImageUrl;

  /// Must match the tapped card's real hero tag exactly (e.g. via the
  /// pager) so the Hero flight always lands on the correct card — both
  /// opening AND dismissing — regardless of which page is on screen.
  final String heroSuffix;

  /// Suffix for this page's *own* Similar/Recently-Visited section cards
  /// only (`product_hero_<id>_sp` / `_rv`). When multiple pager pages are
  /// mounted at once, defaults to [heroSuffix] (fine for the single-page
  /// case) but the pager scopes it per-page to avoid duplicate-tag crashes
  /// between concurrently-mounted pages — it must NOT affect the main
  /// image hero tag above.
  final String? subSectionHeroSuffix;

  /// Fired once when this page finishes expanding to true full screen, and
  /// once when it finishes collapsing back. The pager uses these to swap
  /// its PageController's viewportFraction between 1 (no side gap while
  /// expanded) and the peek fraction (while collapsed) — edge-triggered so
  /// it only swaps exactly at the threshold, not every scroll frame.
  final VoidCallback? onFullyExpanded;
  final VoidCallback? onCollapsed;

  /// Fired when the card starts/stops covering the whole screen, so the
  /// pager can stop painting (and blurring) the route underneath while
  /// nothing of it can show.
  final ValueChanged<bool>? onCoversScreenChanged;

  /// When set (e.g. the product was opened from a filtered list matching a
  /// specific attribute like "Color: Red"), the detail screen preselects
  /// this variant instead of defaulting to the first one.
  final int? targetVariantId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialImageUrl,
    this.heroSuffix = '',
    this.subSectionHeroSuffix,
    this.onFullyExpanded,
    this.onCollapsed,
    this.onCoversScreenChanged,
    this.targetVariantId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin, PeekExpandDismissController {
  static const double _peekGap = 6;
  static const double _peekMinInset = 24;
  static const BorderRadius _peekRadius = AppRadius.r20;

  final PageController _imageController = PageController();
  final GlobalKey _upsellSectionKey = GlobalKey();
  final GlobalKey _similarSectionKey = GlobalKey();
  final GlobalKey _recentlyVisitedSectionKey = GlobalKey();
  final GlobalKey _bottomBarKey = GlobalKey();
  int _imagePage = 0;

  /// Add-on module: this page's addon answers — rendered inline under the
  /// variants and read by the bottom bar's ADD.
  final AddonController _addons = AddonController();

  /// Measured height of [ProductDetailBottomBar], so [FloatingCartBar] (also
  /// positioned inside the body Stack, since applyBottomInset is false here)
  /// floats above it instead of being drawn underneath its opaque surface.
  double _bottomBarHeight = 0;

  void _scheduleBottomBarMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _bottomBarKey.currentContext?.size?.height;
      if (height != null && height != _bottomBarHeight) {
        setState(() => _bottomBarHeight = height);
      }
    });
  }

  double get _expandedHeight => context.screenHeight * 0.38;

  @override
  double get collapseThreshold =>
      _expandedHeight - kToolbarHeight - context.topSafePadding;

  @override
  void onFullyExpanded() => widget.onFullyExpanded?.call();

  @override
  void onCollapsed() => widget.onCollapsed?.call();

  @override
  void onCoversScreenChanged(bool covers) =>
      widget.onCoversScreenChanged?.call(covers);

  @override
  void initState() {
    super.initState();
    initPeekExpand(this);
    context.read<ProductDetailCubit>().loadProductDetail(
      widget.productId.toString(),
      targetVariantId: widget.targetVariantId,
    );
    context.read<RecentlyVisitedCubit>().getRecentlyVisited(
      productId: widget.productId.toString(),
    );
    context.read<AddRecentlyVisitedProductCubit>().addRecentlyVisitedProduct(
      productId: widget.productId.toString(),
    );
    context.read<RatingsListCubit>().loadRatings(
      productId: widget.productId.toString(),
    );
    context.read<RatingImagesCubit>().applyFilters(widget.productId.toString());
    context.read<CartRecommendationsCubit>().fetchRecommendations(
      latitude: SettingsHiveBox.instance.userLatitude,
      longitude: SettingsHiveBox.instance.userLongitude,
      productId: widget.productId.toString(),
    );
  }

  /// Fired on the *first* add-to-cart of this session (CartButton.onFirstAdd
  /// only fires on the 0→1 transition) — scrolls down to the Upsell
  /// section. Scrolling there naturally also drives the page past the
  /// expand threshold, so it ends up full screen too.
  void _scrollToUpsell() {
    // Upsell first; if it's empty/unmounted fall back to Similar, then
    // Recently Visited.
    final target = [
      _upsellSectionKey,
      _similarSectionKey,
      _recentlyVisitedSectionKey,
    ].where((k) => k.currentContext != null).firstOrNull;
    if (target == null) return;
    ensureVisibleAndFlash(
      context,
      target,
      alignment: 0.1,
      color: context.cs.primary,
    );
  }

  @override
  void dispose() {
    disposePeekExpand();
    _imageController.dispose();
    _addons.dispose();
    super.dispose();
  }

  Widget _buildAppScaffold(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: context.theme.scaffoldBackgroundColor,
      bottomNavigationBar: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          if (state is! ProductDetailLoaded) return const SizedBox.shrink();
          // SizeChangedLayoutNotification only fires on a *change* in size,
          // so the very first time this bar appears (mount, no prior size to
          // diff against) also needs an explicit measure request here.
          _scheduleBottomBarMeasure();
          return NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _scheduleBottomBarMeasure();
              return false;
            },
            child: SizeChangedLayoutNotifier(
              key: _bottomBarKey,
              child: ProductDetailBottomBar(
                product: state.product,
                selectedVariantIndex: state.selectedVariantIndex,
                addonController: _addons,
                onFirstAddToCart: _scrollToUpsell,
                bottomInsetFraction: expandT,
              ),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          BlocListener<ProductDetailCubit, ProductDetailState>(
            listener: (context, state) {
              if (state is ProductDetailLoaded) {
                context.read<SimilarProductCubit>().applyFilters(
                  state.product.id?.toString() ?? '',
                );
                // Add-on module: groups come with product detail for the
                // current coordinates — no separate fetch.
                _addons.setGroups(state.product.addonGroups);
              }
            },
            child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
              builder: (context, state) {
                if (state is ProductDetailLoading ||
                    state is ProductDetailInitial) {
                  return _HeroLoadingView(
                    productId: widget.productId,
                    imageUrl: widget.initialImageUrl,
                    heroSuffix: widget.heroSuffix,
                  );
                }
                if (state is ProductDetailError) {
                  return EmptyStateWidget(
                    imagePath: AssetsConstants.noSearchFound,
                    title: state.message,
                    subtitle: context.translate(
                      LanguageLabelKeys.pullToRefresh,
                    ),
                    onRetry: () => context
                        .read<ProductDetailCubit>()
                        .loadProductDetail(widget.productId.toString()),
                  );
                }
                if (state is ProductDetailLoaded) {
                  return ProductDetailView(
                    product: state.product,
                    productId: widget.productId,
                    heroSuffix: widget.heroSuffix,
                    initialImageUrl: widget.initialImageUrl,
                    subSectionHeroSuffix:
                        widget.subSectionHeroSuffix ?? widget.heroSuffix,
                    selectedVariantIndex: state.selectedVariantIndex,
                    selectedAxisValues: state.selectedAxisValues,
                    imageController: _imageController,
                    scrollController: scrollController,
                    imagePage: _imagePage,
                    isCollapsed: isCollapsed,
                    isExpanded: expandT >= 1,
                    onToggleExpand: toggleExpand,
                    onImagePageChanged: (p) => setState(() => _imagePage = p),
                    upsellSectionKey: _upsellSectionKey,
                    similarSectionKey: _similarSectionKey,
                    recentlyVisitedSectionKey: _recentlyVisitedSectionKey,
                    addonController: _addons,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Positioned(
            // Float above ProductDetailBottomBar, which sits below the body
            // as a separate opaque scaffold slot — without this offset the
            // bar draws underneath it and is never visible.
            bottom: _bottomBarHeight,
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

  @override
  Widget build(BuildContext context) {
    // Same gap on every side, padded out by whatever safe-area inset that
    // side actually needs (status bar on top, gesture bar on bottom) — but
    // floored at _peekMinInset, since devices with a non-overlapping
    // 3-button nav bar report a bottom inset of 0 (that bar lives outside
    // Flutter's canvas entirely), which made the bottom gap collapse to
    // just _peekGap while the top kept its status-bar-driven size.
    final viewPadding = MediaQuery.paddingOf(context);
    final peekMargin = EdgeInsetsDirectional.fromSTEB(
      _peekGap,
      _peekGap + math.max(viewPadding.top, _peekMinInset),
      _peekGap,
      _peekGap + math.max(viewPadding.bottom, _peekMinInset),
    );
    final margin = EdgeInsetsDirectional.lerp(
      peekMargin,
      EdgeInsetsDirectional.zero,
      expandT,
    )!;
    final radius = BorderRadius.lerp(_peekRadius, BorderRadius.zero, expandT)!;

    // Live pull-down feedback: as the user drags past the dismiss threshold,
    // shrink + push the whole card down so image and content visibly move
    // together as one sheet, instead of only reacting once the drag ends
    // (which read as "bounce then snap shut" with no feedback in between).
    final dismissT = (dismissDrag / dismissThreshold).clamp(0.0, 1.0);
    final dismissScale = 1 - (0.06 * dismissT);

    // Frosted backdrop behind the peek card (same idea as a dialog/bottom
    // sheet scrim) — blurs whatever's already painted behind this page
    // (e.g. a peeking neighbour product) plus a fixed dark tint so the
    // card always reads as a distinct floating surface in both light and
    // dark theme. Both fade out once fully expanded (card covers all).
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        handleScrollNotification(n, onDismiss: () => AppNavigator.pop(context));
        return false;
      },
      child: Transform.translate(
        offset: Offset(0, dismissDrag),
        child: Transform.scale(
          scale: dismissScale,
          alignment: Alignment.topCenter,
          child: Container(
            margin: margin,
            clipBehavior: Clip.antiAlias,
            decoration: AppDecorations.box(
              borderRadius: radius,
              // Zero offset + spread so the shadow reads evenly on
              // every edge — an offset shadow (e.g. Offset(0, 8))
              // only shows up on the bottom, leaving top/sides bare
              // and making the card look inconsistently lit.
              boxShadow: [
                BoxShadow(
                  color: context.cs.scrim.withValues(
                    alpha: 0.3 * (1 - expandT) * (1 - dismissT * 0.5),
                  ),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildAppScaffold(context),
          ),
        ),
      ),
    );
  }
}

class _HeroLoadingView extends StatelessWidget {
  final int productId;
  final String? imageUrl;
  final String heroSuffix;

  const _HeroLoadingView({
    required this.productId,
    this.imageUrl,
    this.heroSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.screenHeight;
    final bg = context.cs.surfaceContainerHigh;
    final (memCacheWidth, memCacheHeight) = productHeroMemCacheSize(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: sh * 0.38,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
            child: GestureDetector(
              onTap: () => AppNavigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: AppDecorations.box(
                  color: context.cs.surface.withValues(alpha: 0.9),
                  shape: .circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.cs.scrim.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsetsDirectional.all(
                  ThemeConstants.paddingS,
                ),
                child: Transform.flip(
                  flipX: Directionality.of(context) == TextDirection.rtl,
                  child: AppSvgIcon(
                    AssetsConstants.arrowLeftIcon,
                    size: ThemeConstants.iconS,
                    color: context.cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Hero(
              tag: 'product_hero_$productId$heroSuffix',
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? AppNetworkImage(
                      url: imageUrl!,
                      fit: BoxFit.contain,
                      memCacheWidth: memCacheWidth,
                      memCacheHeight: memCacheHeight,
                      placeholder: ColoredBox(color: bg),
                      errorWidget: ColoredBox(color: bg),
                    )
                  : ColoredBox(color: bg),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _DetailBodySkeleton()),
      ],
    );
  }
}

/// Mirrors [ProductDetailView]'s body shape (name, price, variant chips,
/// description block) below the hero image, so there's no layout jump
/// once the real content swaps in.
class _DetailBodySkeleton extends StatefulWidget {
  const _DetailBodySkeleton();

  @override
  State<_DetailBodySkeleton> createState() => _DetailBodySkeletonState();
}

class _DetailBodySkeletonState extends State<_DetailBodySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box(
    Color color, {
    double? width,
    double height = 14,
    BorderRadius? radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: AppDecorations.box(
        color: color,
        borderRadius: radius ?? AppRadius.r4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = context.cs.surfaceContainerHighest;
    final highlightColor = context.cs.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(baseColor, highlightColor, _controller.value)!;
        return Padding(
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _box(color, width: double.infinity, height: 20),
              AppSpacing.h8,
              _box(color, width: 180, height: 13),
              AppSpacing.h16,
              _box(color, width: 90, height: 24, radius: AppRadius.r8),
              AppSpacing.h16,
              _box(color, width: 100, height: 12),
              AppSpacing.h8,
              Row(
                spacing: ThemeConstants.spaceS,
                children: [
                  for (var i = 0; i < 3; i++)
                    _box(color, width: 64, height: 36, radius: AppRadius.r8),
                ],
              ),
              AppSpacing.h16,
              _box(color, width: double.infinity, height: 12),
              AppSpacing.h8,
              _box(color, width: double.infinity, height: 12),
              AppSpacing.h8,
              _box(color, width: 220, height: 12),
            ],
          ),
        );
      },
    );
  }
}
