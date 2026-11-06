import 'dart:math' as math;

import 'package:customer/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wheel drawing for [SpinWheelDialog] (spin_wheel_dialog.dart), split out to
/// keep the dialog file focused on state and flow.
///
/// - [SpinWheelPainter]: the wheel itself (ring, studs, slices, dividers).
/// - [SpinWheelPointer]: the gold triangle fixed at the top of the wheel that
///   marks the winning slice.

/// Gold rounded triangle resting on the wheel's top edge, tip pointing down.
///
/// It never rotates with the wheel. [wiggleAngle] leans only its tip (the top
/// edge stays put) so the pin "ticks" while the wheel spins.
class SpinWheelPointer extends StatelessWidget {
  /// Diameter of the wheel this pin sits on; the pin is sized from it.
  final double wheelSize;

  /// Pin color (`campaign.theme.pointer_color` from the config API, falling
  /// back to the ring's `border_color` when absent). The pin's gradient and
  /// rim are shades of it.
  final Color ringColor;

  /// Tip lean in radians. The top edge stays fixed; only the tip swings.
  /// 0 = upright.
  final double wiggleAngle;

  // Proportions (fractions of the wheel diameter) taken from the reference
  // art: ~15% wide, ~10.5% tall, with ~3.2% of the pin standing above the
  // wheel's outer edge and the rest resting on the ring.
  static const double _widthFraction = 0.15;
  static const double _heightFraction = 0.105;
  static const double _overhangFraction = 0.032;

  const SpinWheelPointer({
    super.key,
    required this.wheelSize,
    required this.ringColor,
    this.wiggleAngle = 0,
  });

  /// How far the pin stands above the wheel's outer edge. The dialog uses it
  /// to offset the pin upward and to leave room for it above the wheel.
  static double overhangFor(double wheelSize) => wheelSize * _overhangFraction;

  @override
  Widget build(BuildContext context) {
    final size = Size(wheelSize * _widthFraction, wheelSize * _heightFraction);
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        size: size,
        painter: _TrianglePinPainter(
          ringColor: ringColor,
          tipShift: math.tan(wiggleAngle) * size.height,
        ),
      ),
    );
  }
}

/// Downward-pointing triangle with rounded top corners and a softly rounded
/// tip, filled with a light-to-dark gradient of [ringColor], with a light rim
/// and a small drop shadow.
class _TrianglePinPainter extends CustomPainter {
  final Color ringColor;

  /// Horizontal offset of the tip. The top edge never moves; only the tip
  /// (and the sides leading to it) lean left/right.
  final double tipShift;

  const _TrianglePinPainter({required this.ringColor, this.tipShift = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final corner = w * 0.2; // top corner radius
    final tipHalfWidth = w * 0.1; // flat part left before the tip curve
    final tipInset = h * 0.2; // where the straight sides end above the tip
    final tipX = w / 2 + tipShift;
    final path = Path()
      ..moveTo(corner, 0)
      ..lineTo(w - corner, 0)
      ..quadraticBezierTo(w, 0, w - corner * 0.6, corner * 0.9)
      ..lineTo(tipX + tipHalfWidth, h - tipInset)
      ..quadraticBezierTo(tipX, h + h * 0.05, tipX - tipHalfWidth, h - tipInset)
      ..lineTo(corner * 0.6, corner * 0.9)
      ..quadraticBezierTo(0, 0, corner, 0)
      ..close();

    final hsl = HSLColor.fromColor(ringColor);
    Color shade(double delta) =>
        hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();

    canvas.drawShadow(path, AppColors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [shade(0.10), ringColor, shade(-0.12)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = shade(0.20),
    );
  }

  @override
  bool shouldRepaint(_TrianglePinPainter old) =>
      old.ringColor != ringColor || old.tipShift != tipShift;
}

/// Draws the wheel itself: drop shadow, gold ring + studs, one solid/glossy
/// slice per segment, and thin dividers between slices. Rotated as a whole
/// by [SpinWheelDialog] via Transform.rotate; this painter only ever draws
/// it at rotation 0.
class SpinWheelPainter extends CustomPainter {
  /// One fill color per slice, straight from the backend's `spin_wheel`
  /// segments (each segment's own `color`) — not a fixed 2-color alternation.
  final List<Color> sliceColors;

  /// Outer ring color. From `campaign.theme.border_color`.
  final Color ringColor;

  /// Divider-line color between slices. From `campaign.theme.line_color`.
  final Color lineColor;

  /// From `campaign.theme.segment_fill`: "glossy" adds a radial shine per
  /// slice; anything else renders a flat solid fill.
  final bool glossy;

  const SpinWheelPainter({
    required this.sliceColors,
    required this.ringColor,
    required this.lineColor,
    required this.glossy,
  });

  int get count => sliceColors.length;

  @override
  void paint(Canvas canvas, Size size) {
    if (sliceColors.isEmpty) return;
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2;
    final ringWidth = outerRadius * 0.09;
    final wheelRadius = outerRadius - ringWidth;
    final segment = 2 * math.pi / count;

    // Soft drop shadow lifting the whole wheel off the page — a flat
    // gradient ring alone reads as a 2D pie chart no matter the colors.
    canvas.drawCircle(
      center.translate(0, outerRadius * 0.035),
      outerRadius - 1,
      Paint()
        ..color = AppColors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outerRadius * 0.06),
    );

    // Ring — a single solid band in the campaign's ring color.
    final ringCenterR = outerRadius - ringWidth / 2;
    canvas.drawCircle(
      center,
      ringCenterR,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth,
    );

    // Studs around the ring, like bulbs on a real prize wheel — each with
    // its own tiny drop shadow + radial sheen so they read as raised.
    final studCount = count * 3;
    final studRadius = ringWidth * 0.2;
    for (var i = 0; i < studCount; i++) {
      final angle = (i / studCount) * 2 * math.pi;
      final studCenter = Offset(
        center.dx + ringCenterR * math.cos(angle),
        center.dy + ringCenterR * math.sin(angle),
      );
      canvas.drawCircle(
        studCenter.translate(0.6, 1),
        studRadius,
        Paint()..color = AppColors.black.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        studCenter,
        studRadius,
        Paint()
          ..shader =
              RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: const [
                  AppColors.white,
                  AppColors.spinWheelStudHighlight,
                ],
              ).createShader(
                Rect.fromCircle(center: studCenter, radius: studRadius),
              ),
      );
    }

    // Slices — flat solid fill. Glossy (campaign.theme.segment_fill ==
    // "glossy") instead fades each slice from a lighter tint near the
    // wheel's center out to its own base color at the rim — one shared
    // gradient center for every slice, not a per-slice offset shine.
    for (var i = 0; i < count; i++) {
      final base = sliceColors[i];
      final paint = glossy
          ? (Paint()
              ..shader =
                  RadialGradient(
                    colors: [Color.lerp(base, AppColors.white, 0.45)!, base],
                  ).createShader(
                    Rect.fromCircle(center: center, radius: wheelRadius),
                  ))
          : (Paint()..color = base);
      final startAngle = i * segment - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: wheelRadius),
        startAngle,
        segment,
        true,
        paint,
      );
    }

    // Thin divider lines between slices, in the line color.
    final dividerPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5;
    for (var i = 0; i < count; i++) {
      final angle = i * segment - math.pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + wheelRadius * math.cos(angle),
          center.dy + wheelRadius * math.sin(angle),
        ),
        dividerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) =>
      oldDelegate.glossy != glossy ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.lineColor != lineColor ||
      !listEquals(oldDelegate.sliceColors, sliceColors);
}
