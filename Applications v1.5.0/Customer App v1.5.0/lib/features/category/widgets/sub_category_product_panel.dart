import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card.dart';
import 'package:customer/features/products/widgets/product_card_grid.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SubCategoryProductPanel extends StatefulWidget {
  final PaginationLoaded<ProductDataModel> state;
  final ScrollController controller;
  final bool showSidebar;
  // Neighbouring sidebar categories (Blinkit-style). Pulling past the end of
  // a fully-loaded list jumps to [nextCategory]; pulling down past the top
  // jumps to [previousCategory].
  final Category? nextCategory;
  final Category? previousCategory;
  final VoidCallback? onNextCategory;
  final VoidCallback? onPreviousCategory;
  // Fixed above the list (the filter/sort bar).
  final Widget? header;

  const SubCategoryProductPanel({
    super.key,
    required this.state,
    required this.controller,
    this.showSidebar = true,
    this.nextCategory,
    this.previousCategory,
    this.onNextCategory,
    this.onPreviousCategory,
    this.header,
  });

  @override
  State<SubCategoryProductPanel> createState() =>
      _SubCategoryProductPanelState();
}

class _SubCategoryProductPanelState extends State<SubCategoryProductPanel>
    with SingleTickerProviderStateMixin {
  // Drag past an edge is damped so the pull feels weighted.
  static const double _resistance = 0.75;
  // Previous-category header (measured off Blinkit: ~106dp — solid band
  // with the icon + name, fading out over the chevron). It opens with the
  // pull-down; releasing once it's (nearly) fully open switches.
  static const double _topMaxPull = _NeighbourCategoryTeaser.previousHeight;
  static const double _topThreshold = 106;
  // Next-category footer mirrors the header: hidden until the user pulls up
  // past the end of a fully-loaded list, then opens from the bottom (above
  // the cart bar) with the pull; releasing once it's (nearly) fully open
  // switches.
  static const double _bottomMaxPull = _NeighbourCategoryTeaser.nextHeight;
  static const double _bottomThreshold = 92;

  final _topPull = ValueNotifier<double>(0);
  final _bottomPull = ValueNotifier<double>(0);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(_onSettleTick);
  double _settleTopFrom = 0;
  double _settleBottomFrom = 0;
  bool _switched = false;

  bool get _canNext =>
      widget.nextCategory != null &&
      widget.onNextCategory != null &&
      !widget.state.hasMore &&
      !widget.state.isFetchingMore;

  bool get _canPrev =>
      widget.previousCategory != null && widget.onPreviousCategory != null;

  @override
  void dispose() {
    _settle.dispose();
    _topPull.dispose();
    _bottomPull.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    _topPull.value = _settleTopFrom * (1 - t);
    _bottomPull.value = _settleBottomFrom * (1 - t);
  }

  void _settleBack() {
    if (_topPull.value == 0 && _bottomPull.value == 0) return;
    _settleTopFrom = _topPull.value;
    _settleBottomFrom = _bottomPull.value;
    _settle.forward(from: 0);
  }

  void _addPull(
    ValueNotifier<double> pull,
    double delta,
    double max,
    double threshold,
  ) {
    final before = pull.value;
    // Rubber band: each px of drag moves the pull less the further out it is.
    final damping = 1 - 0.5 * (before / max).clamp(0.0, 1.0);
    final after = (before + delta * damping).clamp(0.0, max);
    if (before < threshold && after >= threshold) {
      AppHaptics.tick();
    }
    pull.value = after;
  }

  // Drag back up while the previous-category header is open: the header
  // closes with the finger first; only what's left over scrolls the list.
  double _consumeUpDrag(double delta) {
    final pull = _topPull.value;
    if (pull <= 0) return delta;
    _settle.stop();
    final used = delta < pull ? delta : pull;
    _topPull.value = pull - used;
    return delta - used;
  }

  // Mirror for the footer: dragging back down while it's open closes it with
  // the finger before the list scrolls.
  double _consumeDownDrag(double delta) {
    final pull = _bottomPull.value;
    if (pull <= 0) return delta;
    _settle.stop();
    final used = delta < pull ? delta : pull;
    _bottomPull.value = pull - used;
    return delta - used;
  }

  void _switch(VoidCallback? go) {
    if (_switched || go == null) return;
    _switched = true;
    AppHaptics.impact();
    go();
  }

  void _release() {
    // Finger came back before lifting — it's closing, not switching.
    if (_settle.isAnimating) return;
    if (_bottomPull.value >= _bottomThreshold && _canNext) {
      _switch(widget.onNextCategory);
    } else if (_topPull.value >= _topThreshold && _canPrev) {
      _switch(widget.onPreviousCategory);
    } else {
      _settleBack();
    }
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth != 0 || _switched) return false;
    if (n is OverscrollNotification && n.dragDetails != null) {
      // Clamping physics: the list stays put at its edge and reports the
      // extra drag here — that drag opens the header / arms the footer.
      _settle.stop();
      final delta = n.overscroll * _resistance;
      if (delta > 0 && _canNext && _topPull.value == 0) {
        _addPull(_bottomPull, delta, _bottomMaxPull, _bottomThreshold);
      } else if (delta < 0 && _canPrev && _bottomPull.value == 0) {
        _addPull(_topPull, -delta, _topMaxPull, _topThreshold);
      }
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      // Finger reversed and the list moved again — drop the pending pull.
      _settleBack();
    } else if (n is ScrollEndNotification) {
      _release();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final itemCount = state.data.length;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final showSidebar = widget.showSidebar;

    final crossAxisCount = showSidebar
        ? (isTablet ? 3 : 2)
        : (isTablet ? 5 : 3);

    // Reserve room for the FloatingCartBar overlaid at the bottom so the
    // last row can scroll clear of it.
    final bottomInset =
        context.bottomSafePadding +
        (context.select((CartCubit c) => c.state.totalItems > 0)
            ? FloatingCartBar.barHeight
            : 0);

    final canNext = _canNext;
    final canPrev = _canPrev;
    final swipeable = canNext || canPrev;

    if (state.data.isEmpty && !swipeable) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noSearchFound,
        title: context.translate(LanguageLabelKeys.noProductsFound),
        subtitle: context.translate(LanguageLabelKeys.noProductsInCategory),
      );
    }

    final list = NotificationListener<OverscrollIndicatorNotification>(
      // No glow/stretch — the header/footer is the overscroll feedback.
      onNotification: (n) {
        if (swipeable) n.disallowIndicator();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: widget.controller,
          // Clamping on every platform (no iOS bounce) so an edge drag
          // surfaces as OverscrollNotification; always-scrollable so short
          // lists can be pulled too.
          physics: swipeable
              ? _HeaderPullPhysics(
                  consumeUpDrag: _consumeUpDrag,
                  consumeDownDrag: _consumeDownDrag,
                  parent: const AlwaysScrollableScrollPhysics(),
                )
              : null,
          slivers: [
            if (state.data.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  imagePath: AssetsConstants.noSearchFound,
                  title: context.translate(LanguageLabelKeys.noProductsFound),
                  subtitle: context.translate(
                    LanguageLabelKeys.noProductsInCategory,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ProductCardGrid(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingXS,
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS,
                  ),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8 * (isTablet ? 1.75 : 1.0),
                  mainAxisSpacing: 12 * (isTablet ? 1.75 : 1.0),
                  itemCount: itemCount,
                  itemBuilder: (context, index, cardWidth) => ProductCard(
                    product: state.data[index],
                    siblingProducts: state.data,
                    index: index,
                    cardWidth: cardWidth,
                    onAddTap: () {},
                  ),
                ),
              ),
            if (state.isFetchingMore)
              SliverToBoxAdapter(
                child: ProductCardGrid(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingS,
                    0,
                    ThemeConstants.paddingS,
                    ThemeConstants.paddingS + bottomInset,
                  ),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8 * (isTablet ? 1.75 : 1.0),
                  mainAxisSpacing: 12 * (isTablet ? 1.75 : 1.0),
                  itemCount: crossAxisCount,
                  itemBuilder: (context, index, cardWidth) =>
                      const ProductCardSkeleton(),
                ),
              )
            else
              SliverToBoxAdapter(child: SizedBox(height: 16 + bottomInset)),
          ],
        ),
      ),
    );

    final column = Column(
      children: [
        // Previous-category header opens above the filter/sort bar (as on
        // Blinkit), so the bar always separates it from the product cards.
        if (canPrev)
          // Grows with the pull-down.
          ValueListenableBuilder<double>(
            valueListenable: _topPull,
            builder: (context, pull, _) {
              if (pull <= 0) return const SizedBox.shrink();
              return SizedBox(
                height: pull,
                width: double.infinity,
                // Content scales with the open height (fits it exactly), so
                // the icon and name zoom in as the pull grows and shrink back
                // as it settles on release — as on Blinkit.
                child: _NeighbourCategoryTeaser(
                  category: widget.previousCategory!,
                  height: pull,
                  scale: (pull / _NeighbourCategoryTeaser.previousHeight).clamp(
                    0.3,
                    1.0,
                  ),
                  isPrevious: true,
                ),
              );
            },
          ),
        ?widget.header,
        Expanded(
          child: canNext
              // Lifts the list by the pull so its last row clears the footer
              // opening beneath it.
              ? ClipRect(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _bottomPull,
                    builder: (context, pull, child) => Transform.translate(
                      offset: Offset(0, -pull),
                      child: child,
                    ),
                    child: list,
                  ),
                )
              : list,
        ),
      ],
    );

    if (!canNext) return column;

    return Stack(
      children: [
        column,
        // Next-category footer: grows with the pull-up just above the cart
        // bar; content scales with the open height like the header.
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: ValueListenableBuilder<double>(
            valueListenable: _bottomPull,
            builder: (context, pull, _) {
              if (pull <= 0) return const SizedBox.shrink();
              return Stack(
                children: [
                  _NeighbourCategoryTeaser(
                    category: widget.nextCategory!,
                    height: pull,
                    scale: (pull / _NeighbourCategoryTeaser.nextHeight).clamp(
                      0.3,
                      1.0,
                    ),
                    isPrevious: false,
                  ),
                  // The footer covers the sidebar's right-edge shadow, which
                  // makes the panel look cut off — redraw it on the footer.
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _SidebarEdgeShadow(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The sidebar's right-edge shadow (12% shadow colour, blur 8 + offset 3 in
/// SubCategoryScreen) redrawn as a horizontal fade, itself faded in from the
/// top so it follows the footer's own fade instead of starting as a hard
/// line.
class _SidebarEdgeShadow extends StatelessWidget {
  const _SidebarEdgeShadow();

  @override
  Widget build(BuildContext context) {
    final shadow = context.cs.shadow;
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.19],
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
        child: Container(
          width: 11,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                shadow.withValues(alpha: 0.12),
                shadow.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clamping physics that, while the list sits at its top, first hands an
/// upward drag to [consumeUpDrag] (closing the previous-category header with
/// the finger) and, at its end, a downward drag to [consumeDownDrag] (closing
/// the next-category footer) — scrolling only by whatever they give back.
class _HeaderPullPhysics extends ClampingScrollPhysics {
  final double Function(double delta) consumeUpDrag;
  final double Function(double delta) consumeDownDrag;

  const _HeaderPullPhysics({
    required this.consumeUpDrag,
    required this.consumeDownDrag,
    super.parent,
  });

  @override
  _HeaderPullPhysics applyTo(ScrollPhysics? ancestor) => _HeaderPullPhysics(
    consumeUpDrag: consumeUpDrag,
    consumeDownDrag: consumeDownDrag,
    parent: buildParent(ancestor),
  );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // offset < 0: finger moving up (content would scroll up).
    if (offset < 0 && position.pixels <= position.minScrollExtent) {
      final left = consumeUpDrag(-offset);
      return super.applyPhysicsToUserOffset(position, -left);
    }
    // offset > 0: finger moving down (content would scroll back).
    if (offset > 0 && position.pixels >= position.maxScrollExtent) {
      final left = consumeDownDrag(offset);
      return super.applyPhysicsToUserOffset(position, left);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

/// Blinkit-style neighbour-category teaser, laid out to Blinkit's measured
/// proportions: a solid pastel band holding the icon (page-coloured circle)
/// and bold name, fading out over a small double chevron.
///
/// Fills [height]; the gradient always spans that box, and the content is
/// scaled by [scale] from its bottom edge — so a partly opened teaser shows a
/// smaller icon and name rather than a clipped one.
///
/// Previous (opens under the filter bar on pull-down): icon, name, then the
/// chevron in the fade toward the list. Next (list's last item): the
/// chevron in the fade coming from the list, then name and icon.
class _NeighbourCategoryTeaser extends StatelessWidget {
  final Category category;
  final double height;
  final double scale;
  final bool isPrevious;

  const _NeighbourCategoryTeaser({
    required this.category,
    required this.height,
    required this.scale,
    required this.isPrevious,
  });

  // Natural content heights (sum of the column below, name line ≈ 14.4,
  // chevrons 26).
  static const double previousHeight = 123;
  static const double nextHeight = 107;

  // Share of the teaser taken by the fade, measured off Blinkit: ≈ 31 of
  // 123dp on the header, ≈ 20 of 107dp on the footer.
  static const double _fadeStopPrevious = 0.25;
  static const double _fadeStopNext = 0.19;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = context.cs.primary;
    // Measured off Blinkit: the band is the brand hue at full saturation,
    // 96% lightness on light (#EBFEEE-ish mint) and 9% on dark — taken in
    // HSL so it stays a clean pastel whatever the page tint underneath.
    final band = HSLColor.fromColor(primary)
        .withSaturation(1)
        .withLightness(theme.brightness == Brightness.dark ? 0.09 : 0.96)
        .toColor();

    final chevron = _BouncingChevrons(down: isPrevious, color: primary);
    final name = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingS,
      ),
      child: AppText(
        category.name ?? '',
        style: context.tt.labelLarge?.copyWith(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: context.cs.onSurface,
        ),
        textAlign: .center,
        maxLines: 1,
        overflow: .ellipsis,
      ),
    );
    // Same as the sidebar's selected item: 56dp circle with a faint primary
    // tint, the 50dp image centred in it.
    final icon = Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      // 50×50 matches the sidebar's precache key so the icon is already
      // decoded.
      child: AppNetworkImage(
        url: category.imageUrl ?? '',
        width: 50,
        height: 50,
      ),
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      // Spacing measured off Blinkit (dp).
      children: isPrevious
          ? [
              // Solid band ≈ 92dp…
              const SizedBox(height: 4),
              icon,
              const SizedBox(height: 9),
              name,
              const SizedBox(height: 8),
              // …then the ≈ 31dp fade carrying the chevrons.
              const SizedBox(height: 2),
              chevron,
              const SizedBox(height: 3),
            ]
          : [
              // ≈ 20dp fade carrying the chevrons…
              chevron,
              // …then the solid band.
              name,
              const SizedBox(height: 2),
              icon,
              const SizedBox(height: 8),
            ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        // Fade from the page into a solid band (fade side faces the list).
        gradient: LinearGradient(
          begin: isPrevious ? Alignment.bottomCenter : Alignment.topCenter,
          end: isPrevious ? Alignment.topCenter : Alignment.bottomCenter,
          stops: [0, isPrevious ? _fadeStopPrevious : _fadeStopNext, 1],
          colors: [band.withValues(alpha: 0), band, band],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: column,
            ),
          ),
        ),
      ),
    );
  }
}

/// Three stacked chevrons — biggest at the bottom, then smaller, then
/// smallest on top — bobbing continuously in the direction of travel. Sized
/// to the 26dp slot the teaser layout reserves.
class _BouncingChevrons extends StatefulWidget {
  final bool down;
  final Color color;

  const _BouncingChevrons({required this.down, required this.color});

  @override
  State<_BouncingChevrons> createState() => _BouncingChevronsState();
}

class _BouncingChevronsState extends State<_BouncingChevrons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final down = widget.down;
    final dir = down ? 1.0 : -1.0;
    Widget arrow(double size) => Icon(
      down
          ? Icons.keyboard_arrow_down_rounded
          : Icons.keyboard_arrow_up_rounded,
      color: widget.color,
      size: size,
    );
    return SizedBox(
      width: 28,
      height: 26,
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, dir * 4 * Curves.easeInOut.transform(_bob.value)),
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Biggest always at the bottom, shrinking upward.
            Transform.translate(offset: const Offset(0, 8), child: arrow(24)),
            arrow(18),
            Transform.translate(offset: const Offset(0, -7), child: arrow(13)),
          ],
        ),
      ),
    );
  }
}

/// Filter-chip row placeholder — the top of a category page while it loads.
class SubCategoryFilterBarSkeleton extends StatelessWidget {
  const SubCategoryFilterBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final shade = context.cs.surfaceContainerHigh;
    return SizedBox(
      height: context.heightFraction(0.05),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingS,
          vertical: ThemeConstants.paddingXS,
        ),
        child: Row(
          spacing: ThemeConstants.spaceS,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shade,
                    borderRadius: BorderRadius.circular(ThemeConstants.spaceS),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
