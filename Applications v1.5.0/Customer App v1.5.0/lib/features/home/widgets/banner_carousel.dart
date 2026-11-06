import 'dart:async';

import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/carousel_style.dart';
import 'package:customer/features/home/models/enums/indicator_type.dart';
import 'package:customer/features/home/utils/home_redirect_handler.dart';
import 'package:customer/features/home/utils/responsive_height_helper.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

class BannerCarousel extends StatefulWidget {
  final List<Items> items;
  final Config? config;
  final int sectionPadding;
  final BorderRadius sectionBorderRadius;

  const BannerCarousel({
    super.key,
    required this.items,
    this.config,
    this.sectionPadding = 0,
    this.sectionBorderRadius = BorderRadius.zero,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _controller;
  int _page = 0;
  Timer? _timer;
  bool _controllerReady = false;

  bool get _infinite =>
      widget.config?.infiniteLoop == true && widget.items.length > 1;
  bool get _autoScroll => widget.config?.autoScroll == true;
  int get _speedMs => widget.config?.speedMs ?? 3000;
  CarouselStyle get _style =>
      CarouselStyle.fromRaw(widget.config?.carouselStyle);
  bool get _showDots =>
      IndicatorType.fromRaw(widget.config?.indicator) == IndicatorType.dots &&
      widget.items.length > 1;

  // For infinite loop: start at large offset so backward scroll works.
  int get _initialPage => _infinite ? widget.items.length * 50 : 0;

  int get _itemCount =>
      _infinite ? widget.items.length * 100 : widget.items.length;

  int _realIndex(int i) => i % widget.items.length;

  double get _viewportFraction {
    final isTablet = _isTablet(context);
    switch (_style) {
      case CarouselStyle.peek:
        return isTablet ? 0.6 : 0.78;

      case CarouselStyle.card:
        return isTablet ? 0.65 : 0.90;

      case CarouselStyle.spotLight:
        return isTablet ? 0.6 : 0.72;

      default:
        return 1.0;
    }
  }

  /// The actual width a single carousel item renders at — for styles that
  /// only show a fraction of the screen per item (peek/card/spotlight), this
  /// is narrower than the full screen width. Only peek/card wrap each item in
  /// extra horizontal padding (sectionPadding as a gap) on top of the
  /// PageView's viewportFraction — spotlight renders edge-to-edge within its
  /// fraction, so it must not subtract that gap too.
  double _itemRenderWidth(BuildContext context) {
    final screenWidth = context.screenWidth;
    final hasGap = _style == CarouselStyle.peek || _style == CarouselStyle.card;
    final gap = hasGap && widget.sectionPadding > 0
        ? widget.sectionPadding.toDouble()
        : 0.0;
    return screenWidth * _viewportFraction - (gap * 2);
  }

  double _height(BuildContext context) {
    // Use responsive height if imageAspect is configured
    final aspect = widget.config?.imageAspect?.resolve(_isTablet(context));
    if (aspect != null && aspect.isNotEmpty) {
      return ResponsiveHeightHelper.calculateFromAspect(
        imageAspect: aspect,
        context: context,
        renderWidth: _itemRenderWidth(context),
      );
    }

    // Fallback to style-based calculation
    final width = context.screenWidth;
    final isTablet = _isTablet(context);

    switch (_style) {
      case CarouselStyle.story:
        return isTablet ? width * 0.42 : width * 0.58;

      case CarouselStyle.spotLight:
        return isTablet ? width * 0.30 : width * 0.42;

      case CarouselStyle.peek:
        return isTablet ? width * 0.26 : width * 0.38;

      case CarouselStyle.card:
        return isTablet ? width * 0.24 : width * 0.34;

      case CarouselStyle.fullWidth:
        return isTablet ? width * 0.22 : width * 0.32;
    }
  }

  @override
  void initState() {
    super.initState();
    _page = _initialPage;
    // PageController init deferred to didChangeDependencies —
    // _viewportFraction needs MediaQuery which is unavailable in initState.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerReady) {
      _controllerReady = true;
      _controller = PageController(
        initialPage: _initialPage,
        viewportFraction: _viewportFraction,
      );
      if (_autoScroll &&
          widget.items.length > 1 &&
          _style != CarouselStyle.story) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: _speedMs), (_) {
      if (!mounted) return;
      final page = _controller.hasClients ? _controller.page : null;
      if (page == null) return;
      _controller.animateToPage(
        page.round() + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  String? _imageUrl(BuildContext context, Items item) {
    final imgs = item.images;
    if (imgs != null) {
      if (_isTablet(context)) {
        final tablet = imgs.tablet;
        if (tablet != null && tablet.isNotEmpty) return tablet;
      } else {
        final app = imgs.app;
        if (app != null && app.isNotEmpty) return app;
      }
    }
    return item.imageUrl?.isNotEmpty == true ? item.imageUrl : null;
  }

  void _handleTap(BuildContext context, Items item) {
    handleHomeRedirectTap(
      context,
      redirectType: item.redirectType,
      redirectId: item.redirectId,
      redirectUrl: item.redirectUrl,
      redirectSlug: item.redirectSlug,
      redirectTitle: item.redirectTitle,
      redirectParams: item.redirectParams,
      hasChild: item.hasChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final pad = widget.sectionPadding.toDouble();
    final outerPadding = EdgeInsetsDirectional.symmetric(horizontal: pad);

    // SpotLight: continuous scale+opacity via AnimatedBuilder — carousel_slider style
    if (_style == CarouselStyle.spotLight) {
      final BorderRadius radius = widget.sectionBorderRadius;
      return Padding(
        padding: outerPadding,
        child: SizedBox(
          height: _height(context),
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _infinite ? _itemCount : widget.items.length,
            itemBuilder: (ctx, i) {
              final item = widget.items[_realIndex(i)];
              final url = _imageUrl(ctx, item);

              return AnimatedBuilder(
                animation: _controller,
                builder: (_, child) {
                  double page = _page.toDouble();

                  if (_controller.hasClients) {
                    try {
                      page = _controller.page ?? _page.toDouble();
                    } catch (_) {}
                  }

                  final difference = (page - i).abs();

                  final scale = (1 - (difference * 0.20)).clamp(0.80, 1.0);

                  return Center(
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: GestureDetector(
                  onTap: () => _handleTap(ctx, item),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: url != null
                        ? AppNetworkImage(
                            url: url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: ColoredBox(color: context.cs.outline),
                            errorWidget: ColoredBox(color: context.cs.outline),
                          )
                        : ColoredBox(color: context.cs.outline),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Story style: fullscreen-like story with progress bars
    if (_style == CarouselStyle.story) {
      return Padding(
        padding: outerPadding,
        child: SizedBox(
          height: _height(context),
          child: _StorySlider(
            items: widget.items,
            speedMs: _speedMs,
            autoScroll: _autoScroll,
            infiniteLoop: _infinite,
            borderRadius: widget.sectionBorderRadius,
            onItemTap: _handleTap,
            imageUrlFn: _imageUrl,
          ),
        ),
      );
    }

    // Peek: current image large at left edge, next peeks on right
    if (_style == CarouselStyle.peek) {
      final BorderRadius radius = widget.sectionBorderRadius;
      return Padding(
        padding: outerPadding,
        child: Column(
          mainAxisSize: .min,
          spacing: ThemeConstants.spaceS,
          children: [
            SizedBox(
              height: _height(context),
              child: PageView.builder(
                controller: _controller,
                clipBehavior: Clip.none,
                padEnds: false,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _infinite ? _itemCount : widget.items.length,
                itemBuilder: (ctx, i) {
                  final item = widget.items[_realIndex(i)];
                  final url = _imageUrl(ctx, item);
                  final gap = widget.sectionPadding > 0
                      ? widget.sectionPadding.toDouble()
                      : 10.0;
                  return GestureDetector(
                    onTap: () => _handleTap(ctx, item),
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(horizontal: gap),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: url != null
                            ? AppNetworkImage(
                                url: url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: ColoredBox(
                                  color: context.cs.outline,
                                ),
                                errorWidget: ColoredBox(
                                  color: context.cs.outline,
                                ),
                              )
                            : ColoredBox(color: context.cs.outline),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_showDots)
              _DotsIndicator(
                count: widget.items.length,
                current: _realIndex(_page),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: outerPadding,
      child: Column(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceS,
        children: [
          SizedBox(
            height: _height(context),
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _infinite ? _itemCount : widget.items.length,
              itemBuilder: (ctx, i) {
                final real = _realIndex(i);
                final item = widget.items[real];
                final url = _imageUrl(ctx, item);
                final isCenter = _realIndex(_page) == real;

                Widget image = url != null
                    ? AppNetworkImage(
                        url: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: ColoredBox(color: context.cs.outline),
                        errorWidget: ColoredBox(color: context.cs.outline),
                      )
                    : ColoredBox(color: context.cs.outline);

                Widget slide = GestureDetector(
                  onTap: () => _handleTap(ctx, item),
                  child: _buildSlide(image, isCenter),
                );

                return slide;
              },
            ),
          ),
          if (_showDots)
            _DotsIndicator(
              count: widget.items.length,
              current: _realIndex(_page),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(Widget image, bool isCenter) {
    switch (_style) {
      case CarouselStyle.fullWidth:
        return ClipRRect(
          borderRadius: widget.sectionBorderRadius,
          child: image,
        );

      case CarouselStyle.peek:
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingXS,
            vertical: ThemeConstants.paddingXS,
          ),
          child: ClipRRect(borderRadius: AppRadius.r12, child: image),
        );

      case CarouselStyle.card:
        final cardRadius = widget.sectionBorderRadius != BorderRadius.zero
            ? widget.sectionBorderRadius
            : BorderRadius.circular(0.0);
        final cardPad = widget.sectionPadding > 0
            ? widget.sectionPadding.toDouble()
            : ThemeConstants.paddingS;
        return Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: cardPad),
          child: Material(
            elevation: isCenter ? 6 : 2,
            borderRadius: cardRadius,
            clipBehavior: Clip.antiAlias,
            child: image,
          ),
        );

      case CarouselStyle.story:
        final storyRatio =
            ResponsiveHeightHelper.parseAspectRatio(
              widget.config?.imageAspect?.resolve(_isTablet(context)),
            ) ??
            (9 / 16);
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingXS,
          ),
          child: ClipRRect(
            child: AspectRatio(aspectRatio: storyRatio, child: image),
          ),
        );

      case CarouselStyle.spotLight:
        final slRadius = widget.sectionBorderRadius;
        final slPad = widget.sectionPadding.toDouble();
        return Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: slPad),
          child: ClipRRect(borderRadius: slRadius, child: image),
        );
    }
  }
}

// ── Story Slider ──────────────────────────────────────────────────────────────

class _StorySlider extends StatefulWidget {
  final List<Items> items;
  final int speedMs;
  final bool autoScroll;
  final bool infiniteLoop;
  final BorderRadius borderRadius;
  final void Function(BuildContext, Items) onItemTap;
  final String? Function(BuildContext, Items) imageUrlFn;

  const _StorySlider({
    required this.items,
    required this.speedMs,
    required this.autoScroll,
    required this.infiniteLoop,
    required this.onItemTap,
    required this.imageUrlFn,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<_StorySlider> createState() => _StorySliderState();
}

class _StorySliderState extends State<_StorySlider>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  late AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.speedMs),
    )..addStatusListener(_onStatus);
    if (widget.autoScroll && widget.items.isNotEmpty) _start();
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _advance(1);
  }

  void _start() {
    _progress
      ..stop()
      ..reset()
      ..forward();
  }

  void _advance(int delta) {
    final count = widget.items.length;
    int next = _current + delta;
    if (widget.infiniteLoop) {
      next = next % count;
    } else {
      if (next < 0 || next >= count) return;
    }
    setState(() => _current = next);
    if (widget.autoScroll) _start();
  }

  @override
  void dispose() {
    _progress.removeStatusListener(_onStatus);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_current];
    final url = widget.imageUrlFn(context, item);

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          url != null
              ? AppNetworkImage(
                  url: url,
                  fit: BoxFit.cover,
                  placeholder: ColoredBox(color: context.cs.outline),
                  errorWidget: ColoredBox(color: context.cs.outline),
                )
              : ColoredBox(color: context.cs.outline),

          // Dark gradient at top for progress bar visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: DecoratedBox(
              decoration: AppDecorations.box(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.cs.scrim.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Progress bars
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(widget.items.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: i == 0 ? 0 : ThemeConstants.paddingXS,
                    ),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, _) => LinearProgressIndicator(
                        value: i < _current
                            ? 1.0
                            : i == _current
                            ? _progress.value
                            : 0.0,
                        backgroundColor: context.cs.onInverseSurface.withValues(
                          alpha: 0.35,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          context.cs.onInverseSurface,
                        ),
                        minHeight: 3,
                        borderRadius: AppRadius.r2,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Tap left → prev, tap right → next / redirect
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _advance(-1),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onItemTap(context, item);
                    _advance(1);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dots Indicator ────────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsetsDirectional.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: AppDecorations.box(
            color: active ? context.cs.onSurface : context.cs.outline,
            borderRadius: AppRadius.r3,
          ),
        );
      }),
    );
  }
}
