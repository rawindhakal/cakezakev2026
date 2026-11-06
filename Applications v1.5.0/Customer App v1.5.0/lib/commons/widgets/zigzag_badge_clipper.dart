import 'package:flutter/material.dart';

/// Flat top/left edge (flush with image corner), sawtooth bottom edge — ribbon-tag look.
class ZigzagBadgeClipper extends CustomClipper<Path> {
  const ZigzagBadgeClipper();

  static const double _toothWidth = 3;
  static const double _toothHeight = 3;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height);
    double x = size.width;
    bool dipped = false;
    while (x > 0) {
      final nextX = (x - _toothWidth).clamp(0.0, size.width);
      path.lineTo(nextX, dipped ? size.height : size.height - _toothHeight);
      dipped = !dipped;
      x = nextX;
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
