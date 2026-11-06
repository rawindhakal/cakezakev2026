import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Win-celebration confetti for [SpinWheelDialog] (spin_wheel_dialog.dart).
///
/// The dialog builds a fixed list of [ConfettiParticle]s once and drives a
/// [ConfettiPainter] with an animation value 0 -> 1 each time a spin ends in
/// a win.

/// One confetti piece's fixed fall parameters — only [progress] (0-1,
/// driven by the celebration controller) changes where it's drawn.
class ConfettiParticle {
  // Fraction (0-1) of the canvas width this piece falls down.
  final double startXFrac;
  final double fallSpeed;
  final double driftAmplitude;
  final double driftPhase;
  final double size;
  final Color color;
  final double spin;
  // Fraction of the animation this particle waits before it starts
  // falling, so pieces don't all start in one flat line.
  final double delayFrac;

  const ConfettiParticle({
    required this.startXFrac,
    required this.fallSpeed,
    required this.driftAmplitude,
    required this.driftPhase,
    required this.size,
    required this.color,
    required this.spin,
    required this.delayFrac,
  });
}

/// Confetti falling from above the wheel down past it to the bottom of
/// the screen, spread across the full width with a light side-to-side
/// drift — reads as it "rains" down over the wheel rather than bursting
/// from one point, fading out near the end of the fall.
class ConfettiPainter extends CustomPainter {
  final double progress;
  final List<ConfettiParticle> particles;
  final double startY;
  final double endY;

  const ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.startY,
    required this.endY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    for (final p in particles) {
      final t = ((progress - p.delayFrac) / (1 - p.delayFrac)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      // Each piece falls at its own speed (not a shared distance/t), so
      // the shower has natural depth instead of every piece landing in
      // lockstep — clamped to endY so a fast piece never overshoots.
      final dy = math.min(startY + p.fallSpeed * t, endY);
      final dx =
          p.startXFrac * size.width +
          math.sin(t * math.pi * 2.2 + p.driftPhase) * p.driftAmplitude;
      // Fades in quickly, stays solid, fades out over the last 25% of
      // the fall so pieces don't vanish abruptly mid-air.
      final opacity = t < 0.1 ? t / 0.1 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * t * math.pi);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        Paint()..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
