import 'dart:ui' as ui;

import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Owns the [RepaintBoundary] around the right panel so the outgoing
/// category's page can be frozen into an image right before a swipe switches
/// category — the live widget tree is already rebuilding into the next
/// category's skeleton, so the snapshot is what slides away.
class CategorySwipeTransitionController {
  final GlobalKey boundaryKey = GlobalKey();
  ui.Image? _snapshot;

  /// Must run outside the paint phase (e.g. in a post-frame callback).
  void capture() {
    _snapshot?.dispose();
    _snapshot = null;
    final ro = boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary || !ro.hasSize) return;
    try {
      final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio;
      _snapshot = ro.toImageSync(pixelRatio: dpr ?? 1);
    } catch (_) {
      // No snapshot → the incoming page still slides in, just over nothing.
    }
  }

  ui.Image? _take() {
    final s = _snapshot;
    _snapshot = null;
    return s;
  }

  void dispose() {
    _snapshot?.dispose();
    _snapshot = null;
  }
}

/// Blinkit-style vertical page switch for the category right panel. When
/// [pageKey] changes via a swipe, the captured old page slides out (up for
/// "next", down for "previous") while [child] slides in from the opposite
/// edge — like a vertical PageView between neighbouring categories.
class CategorySwipeTransition extends StatefulWidget {
  final CategorySwipeTransitionController? controller;
  final Object? pageKey;
  final SubCategorySwipe swipe;
  final Widget child;

  const CategorySwipeTransition({
    super.key,
    required this.controller,
    required this.pageKey,
    required this.swipe,
    required this.child,
  });

  /// True while a swipe's slide is running (including the parked start
  /// pose). The page underneath uses it to hold its skeleton until the slide
  /// lands, so loaded content never swaps in — and jumps — mid-motion.
  static bool slidingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SlidingScope>()?.sliding ??
      false;

  @override
  State<CategorySwipeTransition> createState() =>
      _CategorySwipeTransitionState();
}

class _SlidingScope extends InheritedWidget {
  final bool sliding;

  const _SlidingScope({required this.sliding, required super.child});

  @override
  bool updateShouldNotify(_SlidingScope oldWidget) =>
      sliding != oldWidget.sliding;
}

class _CategorySwipeTransitionState extends State<CategorySwipeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  )..addStatusListener(_onStatus);

  ui.Image? _outgoing;
  SubCategorySwipe _direction = SubCategorySwipe.none;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _outgoing == null) return;
    setState(() {
      _outgoing?.dispose();
      _outgoing = null;
    });
  }

  @override
  void didUpdateWidget(covariant CategorySwipeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey == widget.pageKey) return;
    _outgoing?.dispose();
    _outgoing = widget.controller?._take();
    if (widget.swipe == SubCategorySwipe.none) {
      _outgoing?.dispose();
      _outgoing = null;
      _direction = SubCategorySwipe.none;
      _anim.value = 1;
      return;
    }
    _direction = widget.swipe;
    // Park at the start pose and only run once the switch's heavy first
    // frame (new page build, loading state) is out of the way — otherwise
    // that frame eats most of the slide and it looks like a hard cut.
    _anim.value = 0;
    final key = widget.pageKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.pageKey != key) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.pageKey == key) _anim.forward(from: 0);
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _outgoing?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = RepaintBoundary(
      key: widget.controller?.boundaryKey,
      child: widget.child,
    );
    if (widget.controller == null) return live;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _anim,
          child: live,
          builder: (context, child) {
            // Eased at both ends so the switch starts gently instead of
            // jumping off the mark.
            final t = Curves.easeInOutCubic.transform(_anim.value);
            final h = box.maxHeight;
            // +1: content travels upward (next); -1: downward (previous).
            final sign = _direction == SubCategorySwipe.previous ? -1.0 : 1.0;
            final animating = _direction != SubCategorySwipe.none && t < 1;
            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(0, animating ? sign * h * (1 - t) : 0),
                  child: _SlidingScope(sliding: animating, child: child!),
                ),
                if (_outgoing != null && animating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: Offset(0, -sign * h * t),
                        child: RawImage(image: _outgoing, fit: BoxFit.fill),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
