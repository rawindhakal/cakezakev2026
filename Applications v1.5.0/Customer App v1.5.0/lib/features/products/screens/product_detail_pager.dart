import 'dart:ui';

import 'package:customer/commons/widgets/app_network_video.dart';
import 'package:customer/features/cart/cubit/cart_recommendations_cubit.dart';
import 'package:customer/features/products/cubit/add_recently_visited_product_cubit.dart';
import 'package:customer/features/products/cubit/product_detail_cubit.dart';
import 'package:customer/features/products/cubit/rating_images_cubit.dart';
import 'package:customer/features/products/cubit/ratings_list_cubit.dart';
import 'package:customer/features/products/cubit/recently_visited_cubit.dart';
import 'package:customer/features/products/cubit/serviceability_cubit.dart';
import 'package:customer/features/products/cubit/similar_product_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/screens/product_detail_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Hosts the product detail screen(s) opened from a list. With a sibling
/// [productList] (length > 1) it renders a horizontally swipeable
/// PageView with a ~15% peek of neighbouring products at rest, like a
/// stack of cards. A single-product entry point (no list, or list of 1 —
/// e.g. deep links/notifications) falls back to one plain full page.
class ProductDetailPager extends StatefulWidget {
  final int productId;
  final String? initialImageUrl;
  final String heroSuffix;
  final List<ProductDataModel>? productList;
  final int initialIndex;

  const ProductDetailPager({
    super.key,
    required this.productId,
    this.initialImageUrl,
    this.heroSuffix = '',
    this.productList,
    this.initialIndex = 0,
  });

  @override
  State<ProductDetailPager> createState() => _ProductDetailPagerState();
}

class _ProductDetailPagerState extends State<ProductDetailPager> {
  static const double _viewportFraction = 0.92;

  late final List<ProductDataModel> _products;
  late PageController _pageController;

  /// PageView keeps neighbouring pages mounted at once, and every page's
  /// main image hero tag must match its own real card (see [_buildPage]).
  /// If two mounted pages both took part at pop time, Flutter would fly
  /// *both* Heroes back simultaneously. So only the currently-active
  /// (visible) page has heroes enabled — every other mounted page sits
  /// under `HeroMode(enabled: false)`, which hero lookup skips entirely.
  late int _activeIndex;

  /// Whether the active page is fully scrolled-up to true full screen.
  /// While true, the PageController is swapped to viewportFraction 1 so
  /// expanding ever reaches a real edge-to-edge width with no residual
  /// side gap — the peek fraction only applies while collapsed.
  bool _activeIsExpanded = false;

  /// Whether the active card currently fills the whole screen edge-to-edge
  /// (see [ProductDetailScreen.onCoversScreenChanged]). While true nothing
  /// behind it can show, so the frosted backdrop is switched off and this
  /// route turns opaque — the Overlay then stops painting the screen
  /// underneath every frame, which was most of the raster cost of
  /// scrolling a fully expanded product.
  final ValueNotifier<bool> _activeCoversScreen = ValueNotifier(false);

  /// Page widget per index, built once — see [_buildPage].
  final Map<int, Widget> _pageCache = {};

  ModalRoute<Object?>? _route;

  /// Upsell isn't per-product (no such endpoint) — same cart-wide block
  /// used at checkout — so one cubit, fetched once, is shared by every
  /// page instead of refetching per swiped-to product.
  final CartRecommendationsCubit _recommendationsCubit =
      CartRecommendationsCubit();

  @override
  void initState() {
    super.initState();
    _recommendationsCubit.fetchRecommendations();
    final list = widget.productList;
    _products = (list != null && list.isNotEmpty)
        ? list
        : [
            ProductDataModel(
              id: widget.productId,
              images: widget.initialImageUrl != null
                  ? [Images(imageUrl: widget.initialImageUrl)]
                  : null,
            ),
          ];
    _activeIndex = widget.initialIndex.clamp(0, _products.length - 1);
    _pageController = PageController(
      viewportFraction: _products.length > 1 ? _viewportFraction : 1,
      initialPage: _activeIndex,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _setActiveCoversScreen(bool covers) {
    _activeCoversScreen.value = covers;
    final route = _route;
    if (route == null || route.overlayEntries.isEmpty) return;
    // Same flag TransitionRoute flips itself: it resets it to the route's
    // own (non-opaque) value whenever a push/pop transition starts, so the
    // screen below is back in place for the pop/hero. Only take it over
    // once the push has settled.
    if (covers && route.animation?.status != AnimationStatus.completed) {
      return;
    }
    route.overlayEntries.first.opaque = covers;
  }

  @override
  void dispose() {
    _activeCoversScreen.dispose();
    _pageController.dispose();
    _recommendationsCubit.close();
    super.dispose();
  }

  void _setActiveExpanded(bool expanded) {
    if (_activeIsExpanded == expanded || _products.length <= 1) return;
    // Deferred a frame: this can be called from the PageView's own
    // scroll-end notification, and disposing the controller that's still
    // mid-notify (driving that very notification) would throw.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeIsExpanded == expanded) return;
      final oldController = _pageController;
      setState(() {
        _activeIsExpanded = expanded;
        _pageController = PageController(
          viewportFraction: expanded ? 1 : _viewportFraction,
          initialPage: _activeIndex,
        );
      });
      oldController.dispose();
    });
  }

  /// Listens to the PageView's own (depth 0) scroll notifications only —
  /// each page's vertical scroll bubbles through here too, at depth > 0.
  ///
  /// The active page is committed only once the swipe has fully settled,
  /// not via `onPageChanged`: that fires at the 50% mark, mid-animation,
  /// and switching [_activeIndex] there rebuilt every mounted page (hero
  /// tags/callbacks change) inside a single frame of the swipe.
  bool _onPagerScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollEndNotification) {
      final page = _pageController.hasClients
          ? _pageController.page?.round()
          : null;
      if (page != null && page != _activeIndex) {
        setState(() => _activeIndex = page);
        // A freshly-swiped-to page always starts collapsed.
        _setActiveExpanded(false);
      }
    }
    return false;
  }

  Widget _buildPage(BuildContext context, int index) {
    // Each page widget is built once and reused as-is, so settling on a new
    // page doesn't rebuild every mounted page's whole subtree — only the
    // cheap HeroMode / keep-alive wrappers below change with [_activeIndex].
    final page = _pageCache[index] ??= _createPage(index);
    if (_products.length <= 1) return page;

    // Pages a couple of swipes away stay mounted, so swiping back and forth
    // doesn't tear a page down and rebuild it from scratch (cubits, API
    // calls, full layout) in the middle of the swipe. Bounded to the
    // active ±2 so a long list doesn't keep every visited page alive.
    return _KeepAlivePage(
      keepAlive: (index - _activeIndex).abs() <= 2,
      // Only the active page takes part in hero flights — see the
      // [_activeIndex] doc above for why.
      // Neighbouring pages stay mounted (and peek in) — only the active
      // one may play its gallery video.
      child: MediaPlaybackScope(
        enabled: index == _activeIndex,
        child: HeroMode(enabled: index == _activeIndex, child: page),
      ),
    );
  }

  Widget _createPage(int index) {
    final product = _products[index];
    // Every page's ProductDetailScreen also renders its own Similar/
    // Recently-Visited sections (hero tags like `product_hero_<id>_sp`) —
    // two concurrently-mounted pages can list the same "similar" product,
    // so those nested section tags always get a page-scoped suffix to
    // dodge duplicate-Hero-tag crashes, independent of active/inactive.
    final subSectionHeroSuffix = '${widget.heroSuffix}_pg$index';
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ProductDetailCubit()),
        BlocProvider(create: (_) => ServiceabilityCubit()),
        BlocProvider(create: (_) => SimilarProductCubit()),
        BlocProvider(create: (_) => RecentlyVisitedCubit()),
        BlocProvider(create: (_) => AddRecentlyVisitedProductCubit()),
        BlocProvider(create: (_) => RatingsListCubit()),
        BlocProvider(create: (_) => RatingImagesCubit()),
        BlocProvider.value(value: _recommendationsCubit),
      ],
      child: ProductDetailScreen(
        productId: product.id ?? widget.productId,
        initialImageUrl: index == widget.initialIndex
            ? widget.initialImageUrl
            : product.images?.coverUrl,
        heroSuffix: widget.heroSuffix,
        subSectionHeroSuffix: subSectionHeroSuffix,
        // Callbacks are fixed for the page's lifetime (the widget is
        // cached), so they check active-ness when fired instead.
        onFullyExpanded: () {
          if (index == _activeIndex) _setActiveExpanded(true);
        },
        onCollapsed: () {
          if (index == _activeIndex) _setActiveExpanded(false);
        },
        onCoversScreenChanged: (covers) {
          if (index == _activeIndex) _setActiveCoversScreen(covers);
        },
        targetVariantId: product.variantId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_products.length <= 1) {
      return _buildPage(context, 0);
    }
    return ClipRect(
      // Matches the per-page dark scrim (see ProductDetailScreen) so any
      // visible gap (e.g. PageView's own end-padding at the first/last
      // page, which has no real neighbour to peek into) reads as part of
      // the same dark backdrop instead of a stray white flash. Middle
      // pages still get symmetric prev+next peek via padEnds' default
      // (true) — only the missing-neighbour edges needed this. Uses the
      // same frosted blur + tint as each page's own scrim (rather than a
      // flat opaque color) so the screen underneath actually shows
      // through dimmed/blurred, like a dialog backdrop — a solid color
      // here would otherwise paint over it before any page's own
      // BackdropFilter gets a chance to blur it.
      child: ValueListenableBuilder<bool>(
        valueListenable: _activeCoversScreen,
        builder: (context, covers, child) => BackdropFilter(
          enabled: !covers,
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: child!,
        ),
        child: ColoredBox(
          color: context.cs.scrim.withValues(alpha: 0.55),
          child: NotificationListener<OverscrollIndicatorNotification>(
            // No stretch/glow when pulling past the first/last product: the
            // Android stretch scales the floating cards, which left a 1px
            // white seam under the card's bottom edge. Depth 0 only — each
            // page's own vertical scroll keeps its indicator.
            onNotification: (n) {
              if (n.depth == 0) n.disallowIndicator();
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: _onPagerScroll,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _products.length,
                // Swipe between products only while collapsed/peeking — once
                // the active page is fullscreen, horizontal drag shouldn't
                // fight its own content's gestures (e.g. image carousel,
                // variant chips).
                physics: _activeIsExpanded
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemBuilder: _buildPage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final bool keepAlive;
  final Widget child;

  const _KeepAlivePage({required this.keepAlive, required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void didUpdateWidget(_KeepAlivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
