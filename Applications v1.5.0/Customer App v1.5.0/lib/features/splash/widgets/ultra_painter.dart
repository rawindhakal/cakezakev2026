import 'dart:math';

import 'package:flutter/material.dart';

class UltraPainter extends CustomPainter {
  final Color color;
  const UltraPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 7.0;
    final padding = 4.0;

    final rect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    /// 🔹 Base circle (very subtle)
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, 0, 2 * pi, false, basePaint);

    final darkPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, 1.3 * pi, false, darkPaint);

    final brightPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2 + 1.3 * pi,
      0.5 * pi, // bright head
      false,
      brightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
