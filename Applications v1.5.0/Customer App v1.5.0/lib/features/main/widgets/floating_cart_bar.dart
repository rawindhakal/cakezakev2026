import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class FloatingCartBar extends StatefulWidget {
  final VoidCallback? onViewCart;

  const FloatingCartBar({super.key, this.onViewCart});

  /// Bar height incl. its own bottom padding — screens whose scrollable
  /// content sits under this bar reserve this much extra bottom space so
  /// the last row isn't hidden behind it.
  static const double barHeight = 62;

  @override
  State<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends State<FloatingCartBar>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  // Morph: collapsed = just the image circle (just-added bubble), expanded = full
  // pill with "View cart" + arrow. Plays forward on 0→n and reverse on n→0,
  // and the bar only slides down after the reverse morph finishes collapsing.
  late final AnimationController _morphCtrl;
  late final Animation<double> _morphAnim;

  int _lastTotalItems = 0;
  List<String> _lastPreviewImages = const [];
  bool _barVisible = false;

  static const double _collapsedSize = 52;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _morphAnim = CurvedAnimation(
      parent: _morphCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // BlocConsumer's listener only fires on subsequent emissions, not the state
    // already in the cubit when this widget mounts — sync initial visuals here
    // so a pre-existing cart shows the bar fully expanded, not hidden/collapsed.
    final initialState = context.read<CartCubit>().state;
    _lastPreviewImages = initialState.previewImages;
    final initialTotal = initialState.totalItems;
    _lastTotalItems = initialTotal;
    _barVisible = initialTotal > 0;
    _morphCtrl.value = initialTotal > 0 ? 1 : 0;
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _morphCtrl.dispose();
    super.dispose();
  }

  static const _slideDuration = Duration(milliseconds: 380);

  void _handleCartChange(CartState state) {
    final total = state.totalItems;
    final images = state.previewImages;
    final imagesChanged = !listEquals(images, _lastPreviewImages);
    _lastPreviewImages = images;
    if (_lastTotalItems == 0 && total > 0) {
      // First item just added — mirrors the remove path: slide the bar up
      // collapsed first, then once it has settled into position, morph open.
      _morphCtrl.value = 0;
      setState(() => _barVisible = true);
      Future.delayed(_slideDuration, () {
        if (mounted && _lastTotalItems > 0) _morphCtrl.forward();
      });
    } else if (_lastTotalItems > 0 && total == 0) {
      // Last item removed — morph back to a circle, then slide the bar down.
      _morphCtrl.reverse().whenComplete(() {
        if (mounted) setState(() => _barVisible = false);
      });
    } else if (total > 0 && !imagesChanged) {
      // Only a qty change — when the preview set changes, the image
      // drop-in / fly-out is the feedback, so skip the stack wobble.
      _shakeCtrl.forward(from: 0.0);
    }
    _lastTotalItems = total;
  }

  double _expandedWidth(int previewCount) {
    if (previewCount <= 1) return 180;
    if (previewCount == 2) return 200;
    return 220;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartCubit, CartState>(
      listener: (context, state) => _handleCartChange(state),
      builder: (context, state) {
        return AnimatedSlide(
          offset: _barVisible ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 380),
          curve: _barVisible ? Curves.easeOutBack : Curves.easeInCubic,
          child: AnimatedOpacity(
            opacity: _barVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingM,
                0,
                ThemeConstants.paddingM,
                ThemeConstants.paddingS,
              ),
              child: Center(
                child: GestureDetector(
                  onTap: widget.onViewCart,
                  // Width eases between 1/2/3-image sizes in step with the
                  // stack's own re-layout instead of jumping.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: _expandedWidth(state.previewImages.length),
                    ),
                    duration: _OverlappingImagesState.layoutDuration,
                    curve: _OverlappingImagesState.layoutCurve,
                    builder: (context, expandedWidth, _) => AnimatedBuilder(
                      animation: _morphAnim,
                      builder: (context, child) {
                        final t = _morphAnim.value;
                        final width =
                            _collapsedSize +
                            (expandedWidth - _collapsedSize) * t;
                        return Container(
                          width: width,
                          height: _collapsedSize,
                          padding: const EdgeInsetsDirectional.only(
                            start: ThemeConstants.paddingS,
                            end: ThemeConstants.paddingS,
                          ),
                          decoration: AppDecorations.box(
                            color: context.cs.primary,
                            borderRadius: AppRadius.pill,
                            boxShadow: [
                              BoxShadow(
                                color: context.cs.primary.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRect(
                            clipper: const _HorizontalClipper(),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: OverflowBox(
                                minWidth: 0,
                                maxWidth: expandedWidth - 16,
                                alignment: AlignmentDirectional.centerStart,
                                child: SizedBox(
                                  width: expandedWidth - 16,
                                  height: 36,
                                  child: Row(
                                    children: [
                                      // ── Overlapping product images ──────────
                                      AnimatedBuilder(
                                        animation: _shakeAnim,
                                        builder: (context, child) =>
                                            Transform.rotate(
                                              angle: _shakeAnim.value,
                                              child: child,
                                            ),
                                        child: _OverlappingImages(
                                          images: state.previewImages,
                                          cartImages: state.imageUrls,
                                        ),
                                      ),

                                      AppSpacing.w10,

                                      // ── View cart + item count ──────────────
                                      Expanded(
                                        child: Opacity(
                                          opacity: t,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: Column(
                                              mainAxisAlignment: .center,
                                              crossAxisAlignment: .start,
                                              spacing: ThemeConstants.spaceXS,
                                              children: [
                                                AppText(
                                                  context.translate(
                                                    LanguageLabelKeys.viewCart,
                                                  ),
                                                  style: context.tt.titleSmall
                                                      ?.copyWith(
                                                        color: context
                                                            .cs
                                                            .onPrimary,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        height: 1,
                                                      ),
                                                ),
                                                AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  transitionBuilder:
                                                      (child, anim) =>
                                                          FadeTransition(
                                                            opacity: anim,
                                                            child: child,
                                                          ),
                                                  child: AppText(
                                                    '${state.totalItems} ${context.translate(state.totalItems == 1 ? LanguageLabelKeys.item : LanguageLabelKeys.items)}',
                                                    key: ValueKey(
                                                      state.totalItems,
                                                    ),
                                                    style: context.tt.bodySmall
                                                        ?.copyWith(
                                                          color: context
                                                              .cs
                                                              .onPrimary
                                                              .withValues(
                                                                alpha: 0.75,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ── Right arrow circle ───────────────────
                                      Opacity(
                                        opacity: t,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: AppDecorations.box(
                                            color: context.cs.scrim.withValues(
                                              alpha: 0.20,
                                            ),
                                            shape: .circle,
                                          ),
                                          child: Transform.flip(
                                            flipX:
                                                Directionality.of(context) ==
                                                TextDirection.rtl,
                                            child: AppSvgIcon(
                                              AssetsConstants.arrowRightIcon,
                                              color: context.cs.onPrimary,
                                              size: ThemeConstants.iconS,
                                              fit: BoxFit.scaleDown,
                                              bakeTint: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Clips only horizontally so the image stack's drop-in / fly-out can travel
/// above the pill while the collapsed morph still hides the overflowing text.
class _HorizontalClipper extends CustomClipper<Rect> {
  const _HorizontalClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height * 4, size.width, size.height * 4);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class _StackItem {
  final String url;
  final AnimationController ctrl;
  bool exiting = false;

  /// Shift in/out of the 3-image window (still in the cart, only scrolled
  /// past by an add/remove elsewhere) — plain fade behind the stack instead
  /// of the drop / fly-out, so each add/remove shows exactly one motion.
  bool quiet = false;

  /// Image decoded — until then the circle isn't built at all, otherwise
  /// CachedNetworkImage starts its own async load and plays its 500ms
  /// placeholder→image fade over the drop.
  bool ready = true;
  int slot;

  _StackItem({required this.url, required this.ctrl, required this.slot});
}

class _OverlappingImages extends StatefulWidget {
  final List<String> images;

  /// Every image in the cart — tells a real add/remove apart from an image
  /// merely entering/leaving the 3-image preview window.
  final Set<String> cartImages;
  const _OverlappingImages({required this.images, required this.cartImages});

  @override
  State<_OverlappingImages> createState() => _OverlappingImagesState();
}

class _OverlappingImagesState extends State<_OverlappingImages>
    with TickerProviderStateMixin {
  static const double _size = 36;
  static const double _overlap = 20;
  static const int _maxCount = 3;

  // Blinkit parity (measured frame-by-frame from the reference recording):
  // a new image starts near-invisible ~80dp up (at the product card), eases
  // down into its slot and fades in over the first half. A removed image
  // holds briefly, rises ~70dp straight up decelerating, and fades out
  // linearly over the whole exit.
  static const double _dropFrom = -80;
  static const double _riseTo = -70;

  static const _enterDuration = Duration(milliseconds: 260);
  static const _exitDuration = Duration(milliseconds: 360);

  static const _enterMove = Curves.fastOutSlowIn;
  static const _enterFade = Interval(0.0, 0.55, curve: Curves.easeIn);
  static const _exitMove = Interval(0.17, 0.67, curve: Curves.easeOut);
  static const _exitFade = Interval(0.17, 1.0);

  // Shared with the pill width so stack and pill re-layout together.
  static const layoutDuration = Duration(milliseconds: 300);
  static const layoutCurve = Curves.easeOutCubic;

  // Cap on waiting for a new image's decode before the drop starts anyway.
  static const _precacheTimeout = Duration(milliseconds: 300);

  static const _quietDuration = Duration(milliseconds: 220);

  final List<_StackItem> _items = [];

  /// Decodes [url] at the circle's size (same cache key [_circle] uses), then
  /// starts the drop — so it never falls in as a placeholder that pops into
  /// the real image mid-flight, and never decodes a full-res bitmap on the
  /// animation's first frame.
  void _startEnter(_StackItem item) {
    item.ctrl
      ..duration = item.quiet ? _quietDuration : _enterDuration
      ..value = 0;
    item.ready = false;
    var started = false;
    void start() {
      if (started || !mounted || item.exiting) return;
      started = true;
      setState(() => item.ready = true);
      item.ctrl.forward(from: 0);
    }

    AppNetworkImage.precache(
      context,
      item.url,
      height: _size,
    ).then((_) => start(), onError: (_) => start());
    Future.delayed(_precacheTimeout, start);
  }

  List<String> get _next => widget.images.take(_maxCount).toList();

  @override
  void initState() {
    super.initState();
    final next = _next;
    for (var i = 0; i < next.length; i++) {
      _items.add(
        _StackItem(
          url: next[i],
          slot: i,
          ctrl: AnimationController(vsync: this, duration: _enterDuration)
            ..value = 1,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _OverlappingImages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _next;
    final cart = widget.cartImages;
    final oldCart = oldWidget.cartImages;

    // Removed from the cart → rise and fade out. Still in the cart (pushed
    // out of the window by a newer add) → quiet fade behind the stack.
    for (final item in _items) {
      if (item.exiting || next.contains(item.url)) continue;
      item.exiting = true;
      item.quiet = cart.contains(item.url);
      item.ctrl
        ..duration = item.quiet ? _quietDuration : _exitDuration
        ..forward(from: 0).whenComplete(() {
          if (!mounted || !item.exiting) return;
          setState(() => _items.remove(item));
          item.ctrl.dispose();
        });
    }

    // Newly added to the cart → drop in from above. Already in the cart
    // (back-filled into the window by a remove) → quiet fade in.
    for (var i = 0; i < next.length; i++) {
      final url = next[i];
      final quiet = oldCart.contains(url);
      final existing = _items.where((e) => e.url == url).firstOrNull;
      if (existing == null) {
        final item = _StackItem(
          url: url,
          slot: i,
          ctrl: AnimationController(vsync: this, duration: _enterDuration),
        )..quiet = quiet;
        _items.add(item);
        _startEnter(item);
      } else {
        existing.slot = i;
        if (existing.exiting) {
          // Came back mid-exit — enter again.
          existing
            ..exiting = false
            ..quiet = quiet;
          _startEnter(existing);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.ctrl.dispose();
    }
    super.dispose();
  }

  Widget _circle(String url) => Container(
    width: _size,
    height: _size,
    decoration: AppDecorations.box(
      shape: .circle,
      color: context.cs.onPrimary,
      border: Border.all(color: context.cs.onPrimary, width: 2.5),
    ),
    // Decode at circle size (matches _startEnter's precache key) instead of
    // the full-res source.
    child: ClipOval(
      child: AppNetworkImage(
        url: url,
        memCacheHeight: (_size * MediaQuery.devicePixelRatioOf(context))
            .round(),
        // Plain fill while a slow image loads — the default logo placeholder
        // flashing inside a falling circle reads as a glitch.
        placeholder: ColoredBox(color: context.cs.onPrimary),
      ),
    ),
  );

  Widget _animated(_StackItem item) {
    return AnimatedBuilder(
      animation: item.ctrl,
      builder: (context, child) {
        final v = item.ctrl.value;
        double dy, opacity;
        if (item.quiet) {
          dy = 0;
          opacity = item.exiting ? 1 - v : v;
        } else if (item.exiting) {
          dy = _riseTo * _exitMove.transform(v);
          opacity = 1 - _exitFade.transform(v);
        } else {
          dy = _dropFrom * (1 - _enterMove.transform(v));
          opacity = _enterFade.transform(v);
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: item.ready
          ? RepaintBoundary(child: _circle(item.url))
          : const SizedBox.square(dimension: _size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _items.where((e) => !e.exiting).length;
    final totalWidth = activeCount == 0
        ? 4.0
        : _size + (activeCount - 1) * (_size - _overlap);

    // Oldest at start (back), latest at end (front). Quiet exits sit behind
    // everything; a real fly-out paints on top so it stays visible while
    // neighbours slide into place.
    final active = _items.where((e) => !e.exiting).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    final quietExits = _items.where((e) => e.exiting && e.quiet);
    final exiting = _items.where((e) => e.exiting && !e.quiet);

    return AnimatedContainer(
      duration: layoutDuration,
      curve: layoutCurve,
      width: totalWidth,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in [...quietExits, ...active, ...exiting])
            AnimatedPositionedDirectional(
              key: ValueKey(item.url),
              duration: layoutDuration,
              curve: layoutCurve,
              start: item.slot * (_size - _overlap),
              top: 0,
              child: _animated(item),
            ),
        ],
      ),
    );
  }
}
