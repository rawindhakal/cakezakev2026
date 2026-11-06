import 'package:flutter/material.dart';

/// Clips a torn-ticket / zigzag edge along the top of its child.
class ZigzagTopClipper extends CustomClipper<Path> {
  const ZigzagTopClipper();

  static const _toothWidth = 10.0;
  static const _zigzagHeight = 6.0;

  @override
  Path getClip(Size size) {
    final toothCount = (size.width / _toothWidth).round();
    final toothW = size.width / toothCount;

    final path = Path()..moveTo(0, _zigzagHeight);

    for (var i = 0; i < toothCount; i++) {
      final x = i * toothW;
      final peakY = i.isEven ? 0.0 : _zigzagHeight;
      path.lineTo(x + toothW / 2, peakY);
      path.lineTo(x + toothW, _zigzagHeight);
    }

    return path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
