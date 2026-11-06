import 'package:flutter/material.dart';

/// Reusable scroll-driven "peek card ⇄ full screen" animation state machine.
///
/// Drives three things off a single [scrollController]:
/// - [expandT]: 0 (collapsed/peek card) → 1 (fully expanded), over
///   [expandThreshold] px of scroll.
/// - [isCollapsed]: flips once scroll passes [collapseThreshold] — for
///   screens that also pin a app bar / title once collapsed.
/// - [dismissDrag]: pull-down distance accumulated while already collapsed
///   and at the top of content, via [handleScrollNotification]; crossing
///   [dismissThreshold] on release should pop the screen (call the
///   `onDismiss` passed to [handleScrollNotification]), otherwise it snaps
///   back to 0 via [snapDismissDragBack].
///
/// The host [State] owns rendering (Container/Transform/Hero/etc using
/// these values) — this mixin only owns the numbers. Host must:
/// 1. Mix in `SingleTickerProviderStateMixin` (or any [TickerProvider]).
/// 2. Call [initPeekExpand] in `initState` and [disposePeekExpand] in
///    `dispose`.
/// 3. Override [collapseThreshold] (and optionally [expandThreshold] /
///    [dismissThreshold] / [onFullyExpanded] / [onCollapsed]).
mixin PeekExpandDismissController<T extends StatefulWidget> on State<T> {
  late final ScrollController scrollController;
  late final AnimationController _snapBackController;
  Animation<double> _snapBackAnimation = const AlwaysStoppedAnimation(0);

  double expandT = 0;
  double dismissDrag = 0;
  bool isCollapsed = false;
  bool _firedFullyExpanded = false;

  /// Scroll distance over which the peek card morphs into full screen.
  double get expandThreshold => 40;

  /// Pull-down distance (while collapsed, at the top) needed to dismiss.
  double get dismissThreshold => 120;

  /// Scroll offset past which [isCollapsed] flips to true. Screen-specific
  /// (usually tied to an expanded app-bar/hero height), so no default.
  double get collapseThreshold;

  /// Fired once when scroll crosses [expandThreshold] (0→1 edge), and once
  /// when it returns to 0 (1→0 edge) — not on every scroll frame.
  void onFullyExpanded() {}
  void onCollapsed() {}

  /// Fired whenever the card starts or stops filling the whole screen
  /// edge-to-edge (fully expanded and not pulled down), i.e. whether
  /// anything behind it can show. Called from scroll/animation listeners,
  /// never during build, so hosts may update ancestors (route opacity,
  /// backdrop) synchronously — before the next frame paints.
  void onCoversScreenChanged(bool covers) {}

  bool _coversScreen = false;

  void _syncCoversScreen() {
    final covers = expandT >= 1 && dismissDrag == 0;
    if (covers == _coversScreen) return;
    _coversScreen = covers;
    onCoversScreenChanged(covers);
  }

  void initPeekExpand(TickerProvider vsync, {ScrollController? controller}) {
    scrollController = controller ?? ScrollController();
    _snapBackController =
        AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (!mounted) return;
          setState(() => dismissDrag = _snapBackAnimation.value);
          _syncCoversScreen();
        });
    scrollController.addListener(_onScroll);
  }

  void disposePeekExpand() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    _snapBackController.dispose();
  }

  void _onScroll() {
    if (!mounted || !scrollController.hasClients) return;
    // Clamp to the real scrollable range, not the raw reported offset —
    // under BouncingScrollPhysics, a page whose content is shorter than the
    // viewport has maxScrollExtent ~0, so a drag can rubber-band the raw
    // offset briefly positive with nothing actually scrolled.
    final offset = scrollController.offset.clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );

    final collapsed = offset > collapseThreshold;
    if (collapsed != isCollapsed) setState(() => isCollapsed = collapsed);

    final t = (offset / expandThreshold).clamp(0.0, 1.0);
    // Always land exactly on the 0/1 ends, so a final sub-0.01 step can't
    // leave the card a hair short of edge-to-edge (or of fully collapsed).
    if ((t - expandT).abs() > 0.01 || (t != expandT && (t == 0 || t == 1))) {
      setState(() => expandT = t);
    }
    _syncCoversScreen();

    if (t >= 1 && !_firedFullyExpanded) {
      _firedFullyExpanded = true;
      onFullyExpanded();
    } else if (t <= 0 && _firedFullyExpanded) {
      _firedFullyExpanded = false;
      onCollapsed();
    }
  }

  void toggleExpand() {
    scrollController.animateTo(
      expandT >= 1 ? 0 : expandThreshold,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// Animates [dismissDrag] back to 0 instead of snapping instantly — keeps
  /// a released-below-threshold drag visually continuous.
  void snapDismissDragBack() {
    if (_snapBackController.isAnimating) return;
    _snapBackAnimation = Tween<double>(begin: dismissDrag, end: 0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOut),
    );
    _snapBackController.forward(from: 0);
  }

  /// Feed every [ScrollNotification] the host's scroll view emits (via
  /// `NotificationListener<ScrollNotification>`) into this. [onDismiss]
  /// fires once a released drag has crossed [dismissThreshold].
  ///
  /// Two platforms report a pull-past-top drag two different ways:
  /// BouncingScrollPhysics (iOS default) never fires OverscrollNotification
  /// — it lets metrics.pixels go negative via ScrollUpdateNotification.
  /// ClampingScrollPhysics (Android default) keeps pixels clamped at 0 and
  /// reports the pulled amount only via OverscrollNotification deltas. Each
  /// platform only ever exercises one branch, so there's no double-counting.
  ///
  /// Both branches only ever grow [dismissDrag] (never shrink it directly):
  /// once released, BouncingScrollPhysics runs its own ballistic bounce-back
  /// animation, which keeps emitting these same notification types with
  /// pixels shrinking back toward 0 — tracking that live would decay the
  /// peak drag distance to ~0 by ScrollEndNotification, always failing the
  /// threshold check. Shrinking only happens explicitly, via
  /// [snapDismissDragBack] or [onDismiss] itself.
  void handleScrollNotification(
    ScrollNotification notification, {
    required VoidCallback onDismiss,
  }) {
    if (!mounted) return;
    if (notification.metrics.axis != Axis.vertical) return;

    final canDismiss = expandT <= 0.01;
    if (!canDismiss) {
      if (dismissDrag != 0) snapDismissDragBack();
      return;
    }

    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < 0) {
      _snapBackController.stop();
      final next = (-notification.metrics.pixels).clamp(
        0.0,
        dismissThreshold * 1.5,
      );
      if (next > dismissDrag) setState(() => dismissDrag = next);
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0) {
      _snapBackController.stop();
      final next = (dismissDrag - notification.overscroll).clamp(
        0.0,
        dismissThreshold * 1.5,
      );
      if (next > dismissDrag) setState(() => dismissDrag = next);
    } else if (notification is ScrollEndNotification && dismissDrag > 0) {
      if (dismissDrag >= dismissThreshold) {
        onDismiss();
      } else {
        snapDismissDragBack();
      }
    }
  }
}
