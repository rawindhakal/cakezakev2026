import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/features/home/models/enums/product_block_enums.dart';
import 'package:customer/features/home/models/enums/tab_style.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/utils/responsive_height_helper.dart';
import 'package:customer/features/home/widgets/product_block.dart';
import 'package:customer/features/products/models/product_list_scope.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ProductTabsBlock extends StatefulWidget {
  final List<ProductTabsData> tabs;
  final String? sectionTitle;
  final String? sectionSubtitle;
  final ProductLayout layout;
  final ProductVariant variant;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final String? textColor;
  final String? imageAspect;
  final TabStyle tabStyle;
  final String? tabImageAspect;
  final Color? activeTabColor;
  final Color? tabTextColor;
  final Color? activeTabTextColor;
  final TabActiveIndicator activeIndicator;
  final TabActiveBgStyle activeBgStyle;
  final Color? activeTabColor2;
  final Color? activeOutlineColor;
  final String? activeBgImageUrl;
  final String? activeBgImageAspect;
  final TabAnimation tabAnimation;
  final int columns;
  final int itemGap;
  final int itemRadius;
  final int blockPadding;
  final int defaultLimit;
  final ValueChanged<ProductDataModel>? onTap;
  final String blockId;
  final ViewMoreTapCallback? onViewMoreTap;

  const ProductTabsBlock({
    super.key,
    required this.tabs,
    this.sectionTitle,
    this.sectionSubtitle,
    this.layout = ProductLayout.grid,
    this.variant = ProductVariant.defaultVariant,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.textColor,
    this.imageAspect,
    this.tabStyle = TabStyle.iconTop,
    this.tabImageAspect,
    this.activeTabColor,
    this.tabTextColor,
    this.activeTabTextColor,
    this.activeIndicator = TabActiveIndicator.underline,
    this.activeBgStyle = TabActiveBgStyle.solid,
    this.activeTabColor2,
    this.activeOutlineColor,
    this.activeBgImageUrl,
    this.activeBgImageAspect,
    this.tabAnimation = TabAnimation.slide,
    this.columns = 3,
    this.itemGap = 8,
    this.itemRadius = 0,
    this.blockPadding = 0,
    this.defaultLimit = 0,
    this.onTap,
    this.blockId = '',
    this.onViewMoreTap,
  });

  @override
  State<ProductTabsBlock> createState() => _ProductTabsBlockState();
}

class _ProductTabsBlockState extends State<ProductTabsBlock>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  // The home sections list is lazy: keep this block alive when scrolled
  // off-screen so the user's selected tab survives scrolling back.
  @override
  bool get wantKeepAlive => true;
  final GlobalKey _tabsStackKey = GlobalKey();
  List<GlobalKey> _tabLabelKeys = const [];
  // Every tab's rect, not just the active one — isScrollable TabBar lays
  // out ALL tabs up front (Row inside a scroll view, not lazy), so an
  // inactive tab's rect is already known before it's ever tapped. Caching
  // all of them means switching tabs can read the target rect straight from
  // this map on the SAME frame as the tap, instead of waiting a frame for a
  // fresh measurement — which is what made the curve box visibly lag behind
  // the tab's own (immediately-painted) background image on every switch.
  Map<int, Rect> _tabRects = {};
  Rect? get _activeLabelRect => _tabRects[_tabController.index];
  // True while the TabBar is auto-scrolling a just-tapped tab into view
  // (isScrollable TabBar does this itself over its own ~300ms scroll
  // animation). The curve's rect was previously always chased with its own
  // separate 250ms ease (see _activeLabelRect's TweenAnimationBuilder
  // below), so during that auto-scroll the curve was easing toward a target
  // that itself kept moving every scroll frame — two independent motions
  // stacked on top of each other, which read as the curve lagging/wobbling
  // behind the tab. Only reproducible on a tab that isn't already fully on
  // screen (needs the auto-scroll), matching "smooth on some tabs, not
  // others". While this is true the rect is applied with zero-duration so
  // the curve tracks the scroll 1:1 instead of re-easing every frame; the
  // eased 250ms curve is reserved for a tap on an already-visible tab.
  bool _isTabBarScrolling = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant ProductTabsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      final previousIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: widget.tabs.length,
        vsync: this,
        initialIndex: previousIndex < widget.tabs.length ? previousIndex : 0,
      );
      _tabRects = {};
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _ensureTabLabelKeys() {
    if (_tabLabelKeys.length != widget.tabs.length) {
      _tabLabelKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }
  }

  // Measures EVERY tab's label bounds relative to _tabsStackKey, not just
  // the active one — isScrollable TabBar lays all tabs out up front, so
  // every rect is already available regardless of which tab is selected or
  // scrolled into view. Caching them all means a tab switch can read its
  // target rect straight from the map (already known from a previous
  // layout pass) instead of needing a fresh post-switch measurement, which
  // used to make the curve box visibly lag a frame behind the tab's own
  // (immediately-painted) background image. Re-run after every layout pass
  // (tap, scroll) since isScrollable TabBar can shift tab positions.
  void _updateAllTabRects() {
    final stackBox =
        _tabsStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;
    final rects = <int, Rect>{};
    for (var index = 0; index < _tabLabelKeys.length; index++) {
      final labelBox =
          _tabLabelKeys[index].currentContext?.findRenderObject() as RenderBox?;
      if (labelBox == null || !labelBox.hasSize) continue;
      // Transform both corners (not just topLeft & labelBox.size) — the
      // label sits inside a FittedBox that may scale it down, so its
      // unscaled labelBox.size can be larger than what's actually painted
      // on screen.
      final topLeft = labelBox.localToGlobal(Offset.zero, ancestor: stackBox);
      final bottomRight = labelBox.localToGlobal(
        labelBox.size.bottomRight(Offset.zero),
        ancestor: stackBox,
      );
      rects[index] = Rect.fromPoints(topLeft, bottomRight);
    }
    if (mounted && !mapEquals(rects, _tabRects)) {
      setState(() => _tabRects = rects);
    }
  }

  // Active tab background: 'fill' paints a decorated box behind the label
  // for any activeBgStyle (solid/gradient/image/none). 'underline' stays
  // the plain built-in TabBar indicator — same as the home builder appbar's
  // category tabs — and doesn't get this decoration. 'outline' is the
  // hand-painted connected line/box (_ConnectedUnderlinePainter) and
  // normally doesn't need this either, EXCEPT for activeBgStyle.image:
  // the request was specifically to show the configured background image
  // inside the active tab even in outline mode, with the painted outline
  // framing it — solid/none stay fill-only, unchanged. Outline+gradient is
  // filled by _ConnectedUnderlinePainter itself, so the gradient follows the
  // curve's own shape instead of a separate inner rounded box.
  bool get _isOutlineGradient =>
      widget.activeIndicator == TabActiveIndicator.outline &&
      widget.activeBgStyle == TabActiveBgStyle.gradient;

  BoxDecoration? _activeDecoration(Color activeColor) {
    final isFill = widget.activeIndicator == TabActiveIndicator.fill;
    final isOutlineImage =
        widget.activeIndicator == TabActiveIndicator.outline &&
        widget.activeBgStyle == TabActiveBgStyle.image;
    if (!isFill && !isOutlineImage) {
      return null;
    }
    const radius = 14.0;
    final radiusValue = BorderRadius.circular(radius);

    switch (widget.activeBgStyle) {
      case TabActiveBgStyle.none:
        return BoxDecoration(borderRadius: radiusValue);
      case TabActiveBgStyle.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [activeColor, widget.activeTabColor2 ?? Colors.white],
          ),
          borderRadius: radiusValue,
        );
      case TabActiveBgStyle.image:
        if (widget.activeBgImageUrl?.isNotEmpty == true) {
          return BoxDecoration(
            borderRadius: radiusValue,
            image: DecorationImage(
              image: AppNetworkImage.provider(widget.activeBgImageUrl!),
              fit: BoxFit.cover,
            ),
          );
        }
        return BoxDecoration(color: activeColor, borderRadius: radiusValue);
      case TabActiveBgStyle.solid:
        return BoxDecoration(color: activeColor, borderRadius: radiusValue);
    }
  }

  Duration get _animationDuration => switch (widget.tabAnimation) {
    TabAnimation.none => Duration.zero,
    TabAnimation.fade ||
    TabAnimation.slide => const Duration(milliseconds: 250),
  };

  Widget _animatedTab(
    bool isActive,
    Widget child,
    BoxDecoration? decoration, {
    double? minWidth,
  }) {
    final container = AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      constraints: minWidth != null ? BoxConstraints(minWidth: minWidth) : null,
      // Now always centered, not just when minWidth is set — the Tab slot
      // (and this chip, since it's also height-forced now) can be taller
      // than a short label's own content, and without an explicit
      // alignment a tight-constrained child paints pinned to the top
      // instead of vertically centered in the extra room.
      alignment: Alignment.center,
      // Same padding whether or not this tab is decorated — gating it on
      // `decoration != null` used to shrink the active tab's content area
      // relative to inactive ones (extra 12/4px eaten on the active tab
      // only), so the two states reserved different room for the same
      // 2-line label instead of the identical box the fixed width/height
      // above are meant to guarantee. Now only the decoration itself
      // (color/image) toggles with isActive, never the layout metrics.
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingXS,
        vertical: ThemeConstants.paddingXS,
      ),
      decoration: decoration,
      child: child,
    );
    if (widget.tabAnimation != TabAnimation.fade) return container;
    return AnimatedSwitcher(
      duration: _animationDuration,
      child: KeyedSubtree(key: ValueKey(isActive), child: container),
    );
  }

  Widget _buildTab(
    BuildContext context,
    ProductTabsData tab, {
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required double tabHeight,
  }) {
    Widget? buildIcon() {
      final iconUrl = tab.images?.displayUrl ?? '';
      if (iconUrl.isEmpty) return null;
      final sw = context.screenWidth;
      final tabIconWidth = sw * 0.060;
      final ratio =
          ResponsiveHeightHelper.parseAspectRatio(widget.tabImageAspect) ?? 1;
      final tabIconHeight = tabIconWidth / ratio;
      return Container(
        width: tabIconWidth,
        height: tabIconHeight,
        clipBehavior: Clip.antiAlias,
        decoration: AppDecorations.box(shape: .circle),
        child: AppNetworkImage(url: iconUrl),
      );
    }

    final decoration = isActive ? _activeDecoration(activeColor) : null;
    final hasPaintedBg =
        (decoration != null && widget.activeBgStyle != TabActiveBgStyle.none) ||
        (isActive && _isOutlineGradient);
    // Painted active tab (fill, or outline+image/gradient)
    // uses the dedicated activeTabTextColor so it reads against whatever
    // color/gradient/photo is behind it, falling back to onPrimary when the
    // admin hasn't set one. Unpainted active states (underline, text-only,
    // hollow outline) keep using activeTabColor for the title instead.
    final labelColor = isActive
        ? (hasPaintedBg
              ? (widget.activeTabTextColor ?? context.cs.onPrimary)
              : activeColor)
        : inactiveColor;
    // Applied to EVERY tab (not just the active one) and independent of
    // isActive/decoration — a tab's width feeds straight into the
    // TabBar's Row layout, so sizing only the active tab made every other
    // tab's slot shift sideways each time selection changed (visible as
    // tabs overlapping / jumping back and forth on tap). Reserving the same
    // width up front for all of them, purely from the configured aspect,
    // keeps the row's layout stable across taps — only the decoration
    // (color/image) changes on selection, never any tab's slot size.
    final activeBgRatio = widget.activeBgStyle == TabActiveBgStyle.image
        ? ResponsiveHeightHelper.parseAspectRatio(widget.activeBgImageAspect)
        : null;
    final activeBgMinWidth = activeBgRatio != null
        ? tabHeight * activeBgRatio
        : null;

    switch (widget.tabStyle) {
      case TabStyle.textOnly:
        return _animatedTab(
          isActive,
          AppText(
            tab.title ?? '',
            style: context.tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
            textAlign: .center,
            maxLines: 2,
            overflow: .ellipsis,
          ),
          decoration,
          minWidth: activeBgMinWidth,
        );

      case TabStyle.iconTop:
        final icon = buildIcon();
        return _animatedTab(
          isActive,
          Column(
            mainAxisSize: .min,
            mainAxisAlignment: .center,
            children: [
              const SizedBox(height: 4),
              if (icon != null) ...[icon, const SizedBox(height: 4)],
              AppText(
                tab.title ?? '',
                style: context.tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
                textAlign: .center,
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ],
          ),
          decoration,
          minWidth: activeBgMinWidth,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.tabs.isEmpty) return const SizedBox.shrink();

    final activeColor = widget.activeTabColor ?? context.cs.primary;
    final inactiveColor = widget.tabTextColor ?? context.cs.onSurfaceVariant;
    final pad =
        (widget.blockPadding > 0 ? widget.blockPadding.toDouble() : 8.0) *
        (AppSizes.isTablet(context) ? 1.5 : 1.0);
    final showMeta = widget.variant != ProductVariant.defaultVariant;
    final isHorizontal = widget.layout == ProductLayout.horizontal;

    const tabHorizontalPad = ThemeConstants.paddingM;
    // Fit the Tab's height to its actual content instead of a generic
    // app-bar-tab-sized constant — a taller Tab box than its content leaves
    // built-in top/bottom whitespace (FittedBox just centers it), stacking
    // with the explicit gap below the tab bar and making it look oversized.
    // textOnly bumped from 28 (single-line height) to fit up to 2 lines —
    // labels now wrap to 2 lines with an ellipsis on a 3rd, so the old
    // single-line box forced FittedBox to scale 2-line text down tiny.
    // iconTop's +60 (was +48, which overflowed by ~2px on device): icon
    // (screenWidth*0.06) + top/bottom 4px gaps + a 2-line label + the
    // active decoration's own 4px top/bottom padding, applied to EVERY
    // tab (not just active) so active and inactive share one fixed height
    // — an active-only height would make the row grow/shrink on tap, the
    // exact reflow bug the earlier fixed-width change was for.
    // Reserve icon room only if the row actually needs it — a fixed
    // `+60` regardless of content wasted space above every label when
    // none of the tabs in this row had an icon configured. Checked across
    // ALL tabs (not per-tab) since every Tab in the row must share the one
    // same tabHeight; whichever tab needs the most (icon vs text-only)
    // decides it for the whole row.
    final rowNeedsIconRoom =
        widget.tabStyle == TabStyle.iconTop &&
        widget.tabs.any((t) => (t.images?.displayUrl ?? '').isNotEmpty);
    final tabHeight = switch (widget.tabStyle) {
      TabStyle.textOnly => 44.0,
      TabStyle.iconTop =>
        rowNeedsIconRoom ? context.screenWidth * 0.060 + 60 : 44.0,
    };
    // Same fixed width for EVERY tab, short or long title alike — a tab's
    // width used to be intrinsic (shrink-wrapped to its own label), which
    // both made each tab a different size AND was the root of the
    // switch-time reflow/overlap bug (an active tab's width changing on
    // selection shifted every tab after it in the row). Bounding all of
    // them to this same width up front also gives the label something
    // finite to wrap inside — see the SizedBox below — instead of the old
    // FittedBox scaling 2-line text down to fit, and forces a single
    // very-long word with no space to break instead of overflowing.
    final tabFixedWidth = (context.screenWidth * 0.19).clamp(60.0, 110.0);

    Widget headerAndTabs = Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        if (showMeta && widget.sectionTitle?.isNotEmpty == true) ...[
          AppText(
            widget.sectionTitle!,
            style: context.tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: widget.textColor.toColor() ?? context.cs.onSurface,
            ),
          ),
          if (widget.sectionSubtitle?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            AppText(
              widget.sectionSubtitle!,
              style: context.tt.bodySmall?.copyWith(
                color:
                    widget.textColor.toColor() ?? context.cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            _ensureTabLabelKeys();
            // 'outline' is the hand-painted connected line/box
            // (_ConnectedUnderlinePainter); 'underline' stays the plain
            // built-in TabBar indicator, matching the simple default used
            // elsewhere (e.g. the home builder's app bar category tabs).
            final isConnectedOutline =
                widget.activeIndicator == TabActiveIndicator.outline;

            final tabBar = TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicatorColor: isConnectedOutline
                  ? Colors.transparent
                  : (widget.activeIndicator == TabActiveIndicator.underline
                        ? activeColor
                        : Colors.transparent),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: activeColor,
              unselectedLabelColor: inactiveColor,
              padding: EdgeInsetsDirectional.zero,
              labelPadding: EdgeInsetsDirectional.symmetric(
                horizontal: tabHorizontalPad,
              ),
              onTap: (_) => setState(() {}),
              tabs: widget.tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                return Tab(
                  height: tabHeight,
                  // Also fixing height here (not just width) forces the
                  // decorated chip (AnimatedContainer, sized to its own
                  // Column via mainAxisSize.min) to stretch to this same
                  // height for every tab — otherwise a short text-only
                  // tab's chip stayed shorter than an icon+2-line tab's,
                  // even though both sat in an equally tall Tab slot, so
                  // switching between them changed the visible chip size.
                  child: SizedBox(
                    width: tabFixedWidth,
                    height: tabHeight,
                    child: KeyedSubtree(
                      key: _tabLabelKeys[index],
                      child: _buildTab(
                        context,
                        tab,
                        isActive: _tabController.index == index,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        tabHeight: tabHeight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );

            if (!isConnectedOutline) {
              return Transform.translate(
                offset: Offset(-tabHorizontalPad, 0),
                child: tabBar,
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateAllTabRects();
            });

            // Extra room reserved purely so the outline box's corner radius
            // has somewhere to go at the first tab: labelPadding alone
            // (tabHorizontalPad) mostly gets eaten by the painter's own
            // gap, leaving a near-flush/square corner there. NOT folded
            // into the translate below — Transform.translate shifts the
            // whole Stack (painter canvas included) as one block without
            // widening it, so adding this to the translate just moved the
            // canvas's right edge left by the same amount, leaving the
            // baseline short of the section's right edge. Left as plain
            // Padding inside the Stack instead: the first tab sits
            // outlineEdgeInset further from the title than a perfect flush
            // line, which is the acceptable side of this trade-off.
            const outlineEdgeInset = 8.0;

            return Transform.translate(
              // TabBar's labelPadding also insets the first tab from the
              // start edge — shift left by that same amount so the tab
              // row's leading edge lines up with the section title above
              // it, not indented.
              offset: const Offset(-tabHorizontalPad, 0),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _isTabBarScrolling = true;
                  } else if (notification is ScrollEndNotification) {
                    _isTabBarScrolling = false;
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _updateAllTabRects();
                  });
                  return false;
                },
                // OverflowBox, not SizedBox: a SizedBox's explicit width is
                // still clamped to whatever max width its parent (the
                // Column inside headerAndTabs, itself inside `content`'s
                // outer Padding(pad)) actually offers — asking for more
                // than that silently does nothing, which is why widening
                // this via SizedBox never visibly changed anything.
                // OverflowBox actually lays its child out wider than that
                // and paints the overflow instead of clamping to it.
                //
                // Widened past the row's normal available width by two
                // amounts: tabHorizontalPad to cancel out the
                // Transform.translate shift above on this (right) side
                // (that translate moves the Stack — painter canvas
                // included — left as one block; left uncompensated, the
                // canvas's own right edge, where the baseline ends, would
                // end up tabHorizontalPad short of the row's own content
                // edge); and `pad`, the outer Padding this whole block sits
                // in (see `content` below), so the baseline runs edge to
                // edge with the section's background — not stopping at the
                // same inset the title/product cards use — same as the
                // request that this line have 0 padding against the
                // screen/card edge on the right, unlike the rest of the
                // section's content.
                // The SizedBox(height: tabHeight) matters: OverflowBox
                // reports its own size as `constraints.biggest`, which
                // needs a bounded height to resolve — a bare Column child
                // gets unbounded (infinite) height from its parent, and an
                // OverflowBox with no size to fall back to there breaks
                // layout entirely (this is what caused the overlap /
                // frozen-scroll regression: not the CustomPaint content,
                // the OverflowBox itself failing to size).
                child: SizedBox(
                  height: tabHeight,
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: 0,
                    maxWidth: constraints.maxWidth + tabHorizontalPad + pad,
                    // outlineEdgeInset padding sits INSIDE the Stack,
                    // around tabBar, not outside it — that's what actually
                    // widens the Stack (and so the Positioned.fill
                    // CustomPaint's canvas) by outlineEdgeInset on each
                    // side. Wrapping the Padding around the whole Stack
                    // instead left the Stack's own local coordinate frame
                    // — and so the painter's available room — unchanged,
                    // since the CustomPaint's canvas is bounded by the
                    // Stack's own size either way.
                    child: Stack(
                      key: _tabsStackKey,
                      children: [
                        if (_activeLabelRect != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              // _activeLabelRect now reads straight from the
                              // _tabRects cache (built from ALL tabs, every
                              // layout pass) — the target tab's rect is
                              // already known before it's tapped, so this
                              // updates the SAME frame as the tab switch,
                              // same as the tab's own bg image. No extra
                              // frame of lag left to paper over with a fade.
                              child: TweenAnimationBuilder<Rect?>(
                                key: ValueKey(_isTabBarScrolling),
                                tween: RectTween(
                                  begin: _activeLabelRect,
                                  end: _activeLabelRect,
                                ),
                                duration: _isTabBarScrolling
                                    ? Duration.zero
                                    : _animationDuration,
                                curve: Curves.easeInOut,
                                builder: (context, animatedRect, _) =>
                                    CustomPaint(
                                      painter: _ConnectedUnderlinePainter(
                                        rect: animatedRect,
                                        color:
                                            widget.activeOutlineColor ??
                                            activeColor,
                                        fillColors: _isOutlineGradient
                                            ? [
                                                activeColor,
                                                widget.activeTabColor2 ??
                                                    Colors.white,
                                              ]
                                            : null,
                                        cornerRadius: 12,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        // Left-only: only the first tab was ever flush
                        // against the box's rounding edge (the row scrolls
                        // and ends naturally past the last tab with plenty
                        // of slack already). Padding on the right too
                        // pushed the baseline's end short of the section's
                        // right edge.
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: outlineEdgeInset,
                          ),
                          child: tabBar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );

    // IndexedStack sizes itself to the largest of ALL children (not just the
    // active one), so an inactive tab's taller row would inflate this one's
    // height. Only the selected tab's products actually need to be built.
    final activeTab = widget.tabs[_tabController.index];
    Widget productContent = KeyedSubtree(
      key: ValueKey(activeTab.id),
      child: ProductBlock(
        products: activeTab.products ?? const [],
        columns: widget.columns,
        layout: widget.layout,
        variant: widget.variant,
        itemGap: widget.itemGap,
        itemRadius: widget.itemRadius,
        limit: activeTab.limit ?? widget.defaultLimit,
        onTap: widget.onTap,
        blockId: '${widget.blockId}_${activeTab.id ?? ''}',
        // Scope comes off the tab, not the section — each tab has its own.
        viewMoreScope: ProductListScope(
          dataSource: activeTab.dataSource,
          categoryIds: activeTab.categoryIds,
          brandIds: activeTab.brandIds,
          filterMode: activeTab.filterMode,
        ),
        onViewMoreTap: widget.onViewMoreTap,
        viewMorePreviewImages: activeTab.viewMorePreviewImages,
      ),
    );

    if (widget.tabAnimation != TabAnimation.none) {
      productContent = AnimatedSwitcher(
        duration: _animationDuration,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          if (widget.tabAnimation == TabAnimation.slide) {
            final slideIn = Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation);
            return ClipRect(
              child: SlideTransition(
                position: slideIn,
                child: FadeTransition(opacity: animation, child: child),
              ),
            );
          }
          return FadeTransition(opacity: animation, child: child);
        },
        child: productContent,
      );
    }

    Widget content = Padding(
      padding: isHorizontal
          ? EdgeInsetsDirectional.symmetric(vertical: pad)
          : EdgeInsetsDirectional.all(pad),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Padding(
            padding: isHorizontal
                ? const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingS,
                  )
                : EdgeInsets.zero,
            child: headerAndTabs,
          ),
          productContent,
        ],
      ),
    );

    if (showMeta &&
        widget.variant == ProductVariant.withBackground &&
        widget.backgroundImageUrl?.isNotEmpty == true) {
      final bgUrl = widget.backgroundImageUrl!;
      final bgContent = content;
      content = LayoutBuilder(
        builder: (ctx, constraints) {
          final ratio = ResponsiveHeightHelper.parseAspectRatio(
            widget.imageAspect,
          );
          final minHeight = ratio != null
              ? ResponsiveHeightHelper.calculateFromAspect(
                  imageAspect: widget.imageAspect,
                  context: ctx,
                  renderWidth: constraints.maxWidth,
                )
              : 0.0;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              width: double.infinity,
              decoration: AppDecorations.box(
                image: DecorationImage(
                  image: AppNetworkImage.provider(bgUrl),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                ),
              ),
              child: bgContent,
            ),
          );
        },
      );
    } else if (showMeta && widget.variant == ProductVariant.withColor) {
      final bgColor = widget.backgroundColor.toColor();
      if (bgColor != null) {
        content = ColoredBox(color: bgColor, child: content);
      }
    }

    return content;
  }
}

// Paints one continuous line across the tab row: flat baseline everywhere,
// except around the active tab, where it traces a rounded-rect box (straight
// left/right sides, rounded corners) whose open bottom edge is the baseline
// itself — like the active tab sits in a notch cut into the line.
class _ConnectedUnderlinePainter extends CustomPainter {
  const _ConnectedUnderlinePainter({
    required this.rect,
    required this.color,
    this.fillColors,
    this.cornerRadius = 8,
  }) : strokeWidth = 2,
       paddingFactor = 0.28;

  final Rect? rect;
  final Color color;
  // Top→bottom gradient filling the notch box (the area the curve traces);
  // null leaves it unfilled.
  final List<Color>? fillColors;
  // Gap between the box and the content it frames, as a fraction of the
  // content's own height — scales the box with whatever it's wrapping
  // (a short text-only label vs. a taller icon+label tab) instead of a
  // fixed pixel gap that's too tight on one and too loose on the other.
  final double paddingFactor;
  final double cornerRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final baselineY = size.height - strokeWidth / 2;
    final path = Path()..moveTo(0, baselineY);

    final r = rect;
    if (r != null && r.width > 0) {
      // Box top sits just above the active tab's own measured content
      // (icon+label for icon-top tabs, just the label for text-only), so
      // the whole tab — not just part of it — sits inside the box.
      final verticalGap = (r.height * paddingFactor).clamp(5.0, 12.0);
      // Left/right margin is a fixed value, NOT scaled by r.height like the
      // vertical gap — it used to share `gap` with the vertical side, so a
      // tall icon+label tab (bigger r.height) got a bigger horizontal gap
      // too, eating more of the first/last tab's fixed edge inset than a
      // short text-only tab did. That made the icon-style box sit visibly
      // closer to the screen edge than the text-only box, even though both
      // have the same edge inset to work with.
      const horizontalGap = 8.0;
      final topY = (r.top - verticalGap).clamp(strokeWidth / 2, baselineY);
      final left = (r.left - horizontalGap).clamp(0.0, size.width);
      final right = (r.right + horizontalGap).clamp(0.0, size.width);
      final vertRadius = baselineY - topY;
      final horizRadius = (right - left) / 2;
      final baseRadius = cornerRadius.clamp(
        0.0,
        horizRadius.clamp(0.0, vertRadius),
      );
      // Bounded independently per side by distance to that side's canvas
      // edge — near the first/last tab the box can sit flush against
      // 0/size.width on just one side, so the corner there degrades to
      // whatever radius still fits instead of forcing both corners square,
      // and never goes negative (which would fold the curve into a hook).
      final leftRadius = baseRadius.clamp(0.0, left);
      final rightRadius = baseRadius.clamp(0.0, size.width - right);

      // Each corner is a quadratic with its control point pinned to the
      // sharp (unrounded) corner it replaces, so the curve bulges outward
      // — the same look as a rounded-rectangle border radius.
      final fills = fillColors;
      if (fills != null && fills.length >= 2) {
        final fillPath = Path()
          ..moveTo(left - leftRadius, baselineY)
          ..quadraticBezierTo(left, baselineY, left, baselineY - leftRadius)
          ..lineTo(left, topY + leftRadius)
          ..quadraticBezierTo(left, topY, left + leftRadius, topY)
          ..lineTo(right - rightRadius, topY)
          ..quadraticBezierTo(right, topY, right, topY + rightRadius)
          ..lineTo(right, baselineY - rightRadius)
          ..quadraticBezierTo(right, baselineY, right + rightRadius, baselineY)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..style = PaintingStyle.fill
            ..shader =
                LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: fills,
                ).createShader(
                  Rect.fromLTRB(
                    left - leftRadius,
                    topY,
                    right + rightRadius,
                    baselineY,
                  ),
                ),
        );
      }

      path
        ..lineTo(left - leftRadius, baselineY)
        ..quadraticBezierTo(left, baselineY, left, baselineY - leftRadius)
        ..lineTo(left, topY + leftRadius)
        ..quadraticBezierTo(left, topY, left + leftRadius, topY)
        ..lineTo(right - rightRadius, topY)
        ..quadraticBezierTo(right, topY, right, topY + rightRadius)
        ..lineTo(right, baselineY - rightRadius)
        ..quadraticBezierTo(right, baselineY, right + rightRadius, baselineY);
    }

    path.lineTo(size.width, baselineY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectedUnderlinePainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.fillColors, fillColors) ||
      oldDelegate.strokeWidth != strokeWidth;
}
