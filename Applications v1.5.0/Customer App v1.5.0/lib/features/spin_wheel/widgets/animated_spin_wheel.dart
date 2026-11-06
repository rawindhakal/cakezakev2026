// Self-contained, auto-rotating spin wheel widget — pure CustomPainter,
// no image assets. Entire color theme derives from one hex color string
// (segments, bezel, hub, pointer, gloss highlight all re-shaded from it).

import 'dart:math' as math;
import 'package:customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AnimatedSpinWheel extends StatefulWidget {
  /// Single hex color that drives the ENTIRE theme of the wheel.
  /// Accepts "#RRGGBB", "RRGGBB", "#AARRGGBB" or "AARRGGBB".
  final String hexColor;

  /// Optional per-wedge colors (hex strings). Wedge `i` uses
  /// `segmentColors[i % length]`. When null/empty, wedges alternate light/dark
  /// shades of [hexColor].
  final List<String>? segmentColors;

  /// Overall diameter of the widget.
  final double size;

  /// How many wedges the wheel is divided into.
  final int segmentCount;

  /// How long one full 360° rotation takes. Lower = faster spin.
  final Duration rotationDuration;

  /// Text shown on the fixed center hub (matches the reference image).
  final String centerLabel;

  /// Spin direction. true = clockwise (default), false = counter-clockwise.
  final bool clockwise;

  /// Rotation (radians) of the fixed pointer around the wheel center.
  /// 0 = top (default), -pi/2 = left, pi/2 = right.
  final double pointerAngle;

  const AnimatedSpinWheel({
    super.key,
    required this.hexColor,
    this.segmentColors,
    this.size = 300,
    this.segmentCount = 12,
    this.rotationDuration = const Duration(seconds: 6),
    this.centerLabel = 'SPIN',
    this.clockwise = true,
    this.pointerAngle = 0,
  });

  @override
  State<AnimatedSpinWheel> createState() => _AnimatedSpinWheelState();
}

class _AnimatedSpinWheelState extends State<AnimatedSpinWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.rotationDuration,
    )..repeat(); // <-- auto animation forever, no user interaction required
  }

  @override
  void didUpdateWidget(covariant AnimatedSpinWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the caller changes the spin speed on the fly, apply it smoothly.
    if (oldWidget.rotationDuration != widget.rotationDuration) {
      _controller.duration = widget.rotationDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = _hexToColor(widget.hexColor);
    // Parsed once per build, not once per animation frame.
    final segmentColors = widget.segmentColors?.map(_hexToColor).toList();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double turns = widget.clockwise
            ? _controller.value
            : -_controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          // Continuously animating — keep its repaints off the page behind it.
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SpinWheelPainter(
                rotation: turns * 2 * math.pi,
                baseColor: baseColor,
                segmentColors: segmentColors,
                segmentCount: widget.segmentCount,
                centerLabel: widget.centerLabel,
                pointerAngle: widget.pointerAngle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Parses "#RRGGBB", "RRGGBB", "#AARRGGBB" or "AARRGGBB" into a [Color].
/// Falls back to a pleasant default blue if parsing fails.
Color _hexToColor(String hexString) {
  String hex = hexString.trim().replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  try {
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return AppColors.spinWheelFallbackHub; // fallback default
  }
}

/// Gold rim palette (light -> mid -> dark) shared by bezel, hub ring, pointer.
const List<Color> _goldColors = AppColors.spinWheelGoldRim;
const Color _goldGroove = AppColors.spinWheelGrooveGold;

class _SpinWheelPainter extends CustomPainter {
  final double rotation;
  final Color baseColor;
  final List<Color>? segmentColors;
  final int segmentCount;
  final String centerLabel;
  final double pointerAngle;

  _SpinWheelPainter({
    required this.rotation,
    required this.baseColor,
    required this.segmentColors,
    required this.segmentCount,
    required this.centerLabel,
    required this.pointerAngle,
  });

  // ---- Color helpers, all derived from the single baseColor ----

  Color _shade(Color c, double lightnessDelta, {double saturationDelta = 0}) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + saturationDelta).clamp(0.0, 1.0))
        .toColor();
  }

  Color _hue(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withHue((hsl.hue + delta) % 360).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2;
    final Rect full = Rect.fromCircle(center: center, radius: radius);

    // Default wedge palette: 12 bright rainbow colors, clockwise from the
    // top wedge (red). Repeats if segmentCount is larger.
    const defaultPalette = AppColors.spinWheelSegmentFallback;
    Color rainbow(int i) => defaultPalette[i % defaultPalette.length];
    final Color dividerColor = _shade(baseColor, -0.32);

    // ---------------- Outer bezel: raised 3D gold ring ----------------
    final double innerRadius = radius * 0.88;
    canvas.drawShadow(
      Path()..addOval(full),
      AppColors.black87,
      radius * 0.05,
      false,
    );
    // Thin dark outer edge.
    canvas.drawCircle(center, radius, Paint()..color = _goldGroove);
    // Gold body: bright top, warm orange bottom.
    final double bodyRadius = radius * 0.985;
    canvas.drawCircle(
      center,
      bodyRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.spinWheelHubGoldGradient,
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: bodyRadius)),
    );
    // Inner lip of the ring: reversed gradient so it reads as a bevel
    // stepping down toward the wheel face.
    final double lipRadius = innerRadius + radius * 0.045;
    canvas.drawCircle(
      center,
      lipRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.spinWheelHubGoldStart,
            AppColors.spinWheelHubGoldEnd,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: lipRadius)),
    );
    // Dark groove between the ring and the wedges.
    canvas.drawCircle(
      center,
      innerRadius + radius * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.03
        ..color = _goldGroove,
    );
    // Specular shine on the ring: top-left and bottom-right.
    final Paint shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.035
      ..color = AppColors.white.withValues(alpha: 0.75);
    final Rect shineRect = Rect.fromCircle(
      center: center,
      radius: (bodyRadius + lipRadius) / 2,
    );
    canvas.drawArc(shineRect, math.pi * 1.08, math.pi * 0.32, false, shine);
    canvas.drawArc(
      shineRect,
      math.pi * 0.08,
      math.pi * 0.22,
      false,
      shine..color = AppColors.white.withValues(alpha: 0.4),
    );

    // ---------------- Rotating wedges ----------------
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final double segmentAngle = 2 * math.pi / segmentCount;
    final Rect wedgeRect = Rect.fromCircle(
      center: Offset.zero,
      radius: innerRadius,
    );
    final palette = segmentColors;

    for (int i = 0; i < segmentCount; i++) {
      final double startAngle =
          -math.pi / 2 - segmentAngle / 2 + i * segmentAngle;
      final Color wedgeColor = (palette != null && palette.isNotEmpty)
          ? palette[i % palette.length]
          : rainbow(i);

      final Path path = Path()
        ..moveTo(0, 0)
        ..arcTo(wedgeRect, startAngle, segmentAngle, false)
        ..close();

      // 3D tile: light rim (the bevel), then an inset face that is darker at
      // the hub and glossier toward the rim.
      canvas.drawPath(path, Paint()..color = _shade(wedgeColor, 0.22));

      final double inset = segmentAngle * 0.07;
      final Rect faceRect = Rect.fromCircle(
        center: Offset.zero,
        radius: innerRadius * 0.93,
      );
      final Path facePath = Path()
        ..moveTo(0, 0)
        ..arcTo(faceRect, startAngle + inset, segmentAngle - 2 * inset, false)
        ..close();
      canvas.drawPath(
        facePath,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _shade(wedgeColor, -0.14),
              wedgeColor,
              _shade(wedgeColor, 0.06),
            ],
            stops: const [0.25, 0.7, 1.0],
          ).createShader(faceRect),
      );
      // Gloss band near the rim.
      canvas.drawPath(
        facePath,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.white.withValues(alpha: 0.0),
              AppColors.white.withValues(alpha: 0.28),
            ],
            stops: const [0.6, 1.0],
          ).createShader(faceRect),
      );
      // Thin darker edge under the face for depth.
      canvas.drawPath(
        facePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.008
          ..color = _shade(wedgeColor, -0.2).withValues(alpha: 0.6),
      );
    }

    // Dark dividers on top of the bevels
    final Paint dividerPaint = Paint()
      ..color = dividerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.012;
    for (int i = 0; i < segmentCount; i++) {
      final double angle = -math.pi / 2 - segmentAngle / 2 + i * segmentAngle;
      canvas.drawLine(
        Offset.zero,
        Offset(innerRadius * math.cos(angle), innerRadius * math.sin(angle)),
        dividerPaint,
      );
    }
    canvas.restore();

    // ---------------- Fixed glossy highlight ----------------
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.white.withValues(alpha: 0.28),
                AppColors.white.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: center - Offset(radius * 0.35, radius * 0.4),
                radius: radius * 0.9,
              ),
            ),
    );
    canvas.restore();

    // ---------------- Fixed 3D hub ----------------
    final double hubRadius = radius * 0.31;
    final Rect hubRect = Rect.fromCircle(center: center, radius: hubRadius);
    canvas.drawShadow(Path()..addOval(hubRect), AppColors.black54, 5, false);
    // Outer dark edge for depth.
    canvas.drawCircle(center, hubRadius, Paint()..color = _goldGroove);
    // Raised gold ring (lit from top).
    final double ringOuter = hubRadius * 0.96;
    canvas.drawCircle(
      center,
      ringOuter,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _goldColors,
        ).createShader(Rect.fromCircle(center: center, radius: ringOuter)),
    );
    // Specular highlight along the top-left of the ring.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: hubRadius * 0.9),
      math.pi * 1.05,
      math.pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = hubRadius * 0.05
        ..color = AppColors.white.withValues(alpha: 0.7),
    );
    // Inner bevel: reversed gradient so the ring reads as a raised lip
    // around a recessed face.
    final double faceRadius = hubRadius * 0.8;
    final Rect bevelRect = Rect.fromCircle(
      center: center,
      radius: faceRadius + hubRadius * 0.05,
    );
    canvas.drawCircle(
      center,
      faceRadius + hubRadius * 0.05,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.spinWheelHubGoldStart,
            AppColors.spinWheelPointerGoldEnd,
          ],
        ).createShader(bevelRect),
    );
    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.spinWheelPointerBlueStart,
            AppColors.spinWheelPointerBlueEnd,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: faceRadius)),
    );
    // Soft gloss on the upper half of the face.
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(0, faceRadius * 0.5),
        width: faceRadius * 1.3,
        height: faceRadius * 0.7,
      ),
      Paint()..color = AppColors.white.withValues(alpha: 0.18),
    );

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w900,
          fontSize: hubRadius * 0.58,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: AppColors.black.withValues(alpha: 0.38),
              offset: const Offset(0, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    // ---------------- Fixed pointer (rounded, teal -> purple) ----------------
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pointerAngle);
    canvas.translate(-center.dx, -center.dy);
    final double pw = radius * 0.30;
    final double ph = radius * 0.30;
    final double top = center.dy - radius - ph * 0.05;
    final Path pointer = Path()
      ..moveTo(center.dx - pw / 2, top)
      ..lineTo(center.dx + pw / 2, top)
      ..lineTo(center.dx, top + ph)
      ..close();
    canvas.drawShadow(pointer, AppColors.black54, 3, false);
    canvas.drawPath(
      pointer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.spinWheelCenterTeal, _hue(baseColor, 60)],
        ).createShader(pointer.getBounds()),
    );
    final Rect pointerBounds = pointer.getBounds();
    // 3D gold rim: dark outer edge, gold gradient body, light inner edge.
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = radius * 0.085
        ..color = _goldGroove,
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = radius * 0.06
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _goldColors,
        ).createShader(pointerBounds),
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = radius * 0.014
        ..color = AppColors.white.withValues(alpha: 0.6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpinWheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.segmentColors != segmentColors ||
        oldDelegate.segmentCount != segmentCount ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.pointerAngle != pointerAngle;
  }
}
