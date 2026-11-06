import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loading indicator: a gift box slides in, its lid pops open with a heart and confetti, then it slides away.
class GiftBoxLoader extends StatefulWidget {
  /// Width of the animation; the height is 0.75 x width.
  final double size;
  final Color? color;

  const GiftBoxLoader({super.key, this.size = 72, this.color});

  @override
  State<GiftBoxLoader> createState() => _GiftBoxLoaderState();
}

class _GiftBoxLoaderState extends State<GiftBoxLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size * 0.75,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _GiftPainter(_c.value, base)),
          ),
        ),
      ),
    );
  }
}

double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _GiftPainter extends CustomPainter {
  _GiftPainter(this.t, this.base);
  final double t;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 160, size.height / 120);

    final dark = HSLColor.fromColor(base).withLightness(
      (HSLColor.fromColor(base).lightness - 0.08).clamp(0.0, 1.0),
    ).toColor();
    final ribbon = Color.alphaBlend(Colors.white.withValues(alpha: 0.9), base);

    // slide in -> hold -> slide out
    double dx, alpha;
    if (t < 0.28) {
      final p = _seg(t, 0, 0.28, Curves.easeOutCubic);
      dx = -95 * (1 - p);
      alpha = _seg(t, 0, 0.06);
    } else if (t < 0.70) {
      dx = 0;
      alpha = 1;
    } else {
      final p = _seg(t, 0.70, 1.0, Curves.easeInCubic);
      dx = 95 * p;
      alpha = 1 - _seg(t, 0.94, 1.0);
    }
    if (alpha <= 0) return;

    // ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(80, 104), width: 76, height: 10),
      Paint()..color = const Color(0xFF1A1A2E).withValues(alpha: 0.22 * alpha),
    );

    canvas.save();
    canvas.translate(dx, 0);
    final op = alpha;

    // lid motion
    double lidY, lidRot, lidX;
    if (t < 0.36) {
      lidX = 0; lidY = 0; lidRot = 0;
    } else if (t < 0.46) {
      final p = _seg(t, 0.36, 0.46, Curves.easeOutBack);
      lidX = -7 * p; lidY = -26 * p; lidRot = -30 * p;
    } else if (t < 0.62) {
      final p = _seg(t, 0.46, 0.52);
      lidX = -7 + 2 * p; lidY = -26 + 4 * p; lidRot = -30 + 6 * p;
    } else if (t < 0.72) {
      final p = _seg(t, 0.62, 0.72, Curves.easeInOut);
      lidX = -5 * (1 - p); lidY = -22 * (1 - p); lidRot = -24 * (1 - p);
    } else {
      lidX = 0; lidY = 0; lidRot = 0;
    }

    // confetti
    final conf = <(double, double, Color, double, double)>[
      (-30, -34, const Color(0xFFFFC83D), 3.2, 0.00),
      (30, -30, const Color(0xFF7AD7C8), 2.6, 0.01),
      (-18, -48, base, 2.6, 0.02),
      (20, -46, const Color(0xFFFFC83D), 2.6, 0.005),
      (2, -52, Colors.white, 2.2, 0.015),
    ];
    for (final (cx, cy, col, r, d) in conf) {
      final p = _seg(t, 0.38 + d, 0.74 + d, Curves.easeOut);
      if (p <= 0 || p >= 1) continue;
      final a = (p < 0.7 ? 1.0 : 1 - (p - 0.7) / 0.3) * op;
      canvas.drawCircle(Offset(80 + cx * p, 60 + cy * p), r * (0.4 + 0.6 * p),
          Paint()..color = col.withValues(alpha: a));
    }

    // heart rising from the box
    final hp = _seg(t, 0.40, 0.76, Curves.easeOut);
    if (hp > 0 && hp < 1) {
      final ha = (hp < 0.75 ? 1.0 : 1 - (hp - 0.75) / 0.25) * op;
      canvas.save();
      canvas.translate(80, 66 - 40 * hp);
      canvas.scale(0.25 + 0.8 * math.min(hp * 2, 1));
      canvas.translate(-80, -66);
      final heart = Path()
        ..moveTo(80, 62)
        ..cubicTo(74, 53, 63, 59, 68, 67)
        ..cubicTo(71, 72, 80, 77, 80, 77)
        ..cubicTo(80, 77, 89, 72, 92, 67)
        ..cubicTo(97, 59, 86, 53, 80, 62)
        ..close();
      canvas.drawPath(heart, Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: ha));
      canvas.restore();
    }

    // body
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(52, 66, 56, 38), const Radius.circular(5));
    canvas.drawRRect(body, Paint()..color = base.withValues(alpha: op));
    canvas.drawRect(const Rect.fromLTWH(52, 66, 56, 9), Paint()..color = dark.withValues(alpha: 0.35 * op));
    canvas.drawRect(const Rect.fromLTWH(76, 66, 8, 38), Paint()..color = ribbon.withValues(alpha: op));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(56, 70, 4, 28), const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.28 * op),
    );

    // lid + bow (pivot: lid's bottom-left corner)
    canvas.save();
    canvas.translate(lidX, lidY);
    canvas.translate(48, 68);
    canvas.rotate(lidRot * math.pi / 180);
    canvas.translate(-48, -68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(48, 52, 64, 16), const Radius.circular(5)),
      Paint()..color = dark.withValues(alpha: op),
    );
    canvas.drawRect(const Rect.fromLTWH(76, 52, 8, 16), Paint()..color = ribbon.withValues(alpha: op));
    final loopL = Path()..moveTo(80, 52)..cubicTo(73, 38, 58, 42, 62, 50)..cubicTo(64, 54, 74, 54, 80, 52)..close();
    final loopR = Path()..moveTo(80, 52)..cubicTo(87, 38, 102, 42, 98, 50)..cubicTo(96, 54, 86, 54, 80, 52)..close();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = base.withValues(alpha: op);
    for (final p in [loopL, loopR]) {
      canvas.drawPath(p, Paint()..color = ribbon.withValues(alpha: op));
      canvas.drawPath(p, stroke);
    }
    canvas.drawCircle(const Offset(80, 52), 4, Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: op));
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GiftPainter old) => old.t != t || old.base != base;
}
