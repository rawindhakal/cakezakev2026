import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Circular-reveal theme-switch transition. What's visible at every instant
/// is the real, currently-rendering UI (never a flat placeholder color), so
/// it can never show a blank/wrong-color frame regardless of how slow a
/// rebuild runs. Direction depends on [targetTheme]:
/// - going dark: a transparent hole grows from [position], punched through
///   a snapshot of the old (light) UI — dark spreads outward from the tap.
/// - going light: the old (dark) snapshot is confined to a shrinking circle
///   at [position] instead — dark drains back into the tap point, since the
///   already-live light UI is visible everywhere outside it from frame one.
class ThemeRevealAnimation extends StatefulWidget {
  final Offset position;
  final ui.Image oldSnapshot;
  final ThemeMode targetTheme;
  final VoidCallback onComplete;

  const ThemeRevealAnimation({
    super.key,
    required this.position,
    required this.oldSnapshot,
    required this.targetTheme,
    required this.onComplete,
  });

  @override
  State<ThemeRevealAnimation> createState() => _ThemeRevealAnimationState();
}

class _ThemeRevealAnimationState extends State<ThemeRevealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Matches the reference animation: a single smooth grow with
    // no overshoot — verified frame-by-frame, it never bounces back in.
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    // This widget is inserted in the same frame that applies the new theme,
    // which forces the whole (heavy) tab tree underneath to rebuild. Starting
    // the tween immediately would race that rebuild's jank against the very
    // first animation ticks, turning a smooth grow into a single jump. At
    // radius 0 the hole is invisible anyway (old snapshot still fully
    // covers), so it costs nothing to let that heavy frame finish and settle
    // first, then animate — every following frame is then cheap and smooth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward().then((_) => widget.onComplete());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final maxDistance = [
      (widget.position - Offset.zero).distance,
      (widget.position - Offset(size.width, 0)).distance,
      (widget.position - Offset(0, size.height)).distance,
      (widget.position - Offset(size.width, size.height)).distance,
    ].reduce(math.max);

    final shrink = widget.targetTheme == ThemeMode.light;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final radius = shrink ? maxDistance * (1 - _animation.value) : maxDistance * _animation.value;

        return CustomPaint(
          size: Size.infinite,
          painter: _RevealPainter(image: widget.oldSnapshot, center: widget.position, radius: radius, shrink: shrink),
        );
      },
    );
  }
}

class _RevealPainter extends CustomPainter {
  final ui.Image image;
  final Offset center;
  final double radius;
  final bool shrink;

  _RevealPainter({required this.image, required this.center, required this.radius, required this.shrink});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    if (shrink) {
      // Old snapshot only exists within the shrinking circle — everywhere
      // else is untouched (transparent), showing the already-live new UI.
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
      canvas.drawImageRect(image, src, dst, Paint());
      canvas.restore();
    } else {
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawImageRect(image, src, dst, Paint());
      canvas.drawCircle(center, radius, Paint()..blendMode = BlendMode.clear);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RevealPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.image != image;
  }
}
