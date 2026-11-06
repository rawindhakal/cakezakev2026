import 'dart:math' as math;

import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Stopwatch icon shown next to a product's delivery time. The SVG's
/// `body` group stays static; its `Clock_mith` wedge is hidden and redrawn
/// here as a pie that fills clockwise from 12 o'clock, then drains the same
/// way. The loop starts and ends on the designed three-quarter wedge, so it
/// repeats without a jump.
class DeliveryTimeIcon extends StatefulWidget {
  final double size;

  const DeliveryTimeIcon({super.key, required this.size});

  @override
  State<DeliveryTimeIcon> createState() => _DeliveryTimeIconState();
}

class _DeliveryTimeIconState extends State<DeliveryTimeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Own layer so each tick repaints only the wedge, not the host card.
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Maps the green wedge to transparent; black body follows theme.
            AppSvgIcon(
              AssetsConstants.deliveryTimeIcon,
              size: widget.size,
              color: Colors.transparent,
              useColorMapper: true,
            ),
            CustomPaint(
              painter: _WedgePainter(
                progress: _controller,
                color: context.cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WedgePainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _WedgePainter({required this.progress, required this.color})
    : super(repaint: progress);

  // Wedge geometry from the SVG's 24×24 viewBox: centre (12, 14), radius 7.
  static const double _viewBox = 24;
  static const Offset _center = Offset(12, 14);
  static const double _radius = 7;

  static const double _top = -math.pi / 2;
  static const double _turn = 2 * math.pi;

  // Cycle point where the wedge matches the SVG (3 o'clock round to 12,
  // 270°): a quarter of the way through the drain half.
  static const double _designPhase = 0.625;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    final rect = Rect.fromCircle(
      center: _center * scale,
      radius: _radius * scale,
    );
    final t = (progress.value + _designPhase) % 1;
    // First half: leading edge sweeps round from 12. Second half: trailing
    // edge follows it round, emptying the pie back to where it started.
    final double start;
    final double sweep;
    if (t < 0.5) {
      start = _top;
      sweep = t * 2 * _turn;
    } else {
      final drained = (t - 0.5) * 2 * _turn;
      start = _top + drained;
      sweep = _turn - drained;
    }
    canvas.drawArc(rect, start, sweep, true, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WedgePainter oldDelegate) => oldDelegate.color != color;
}
