import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_palette.dart';
import 'package:flutter/material.dart';

/// Purple 3D "game board" that frames the spin wheel in [SpinWheelDialog].
///
/// Layout, top to bottom (all sizes derive from [wheelSize], so it scales):
///  1. back panel + wider base ([_BoardPainter]) behind everything,
///  2. the sloped console tray ([_TrayPainter]) holding an inset panel
///     ([_InnerPainter]) with two [_StudColumn]s and the SPIN button,
///  3. the wheel [child], drawn LAST so its bottom edge rests on the tray.
///
/// While no spin is available the SPIN button is swapped for [countdown].
class SpinWheelBoard extends StatelessWidget {
  /// Diameter of the wheel [child]; every other dimension is a fraction of it.
  final double wheelSize;

  /// The wheel itself (ring, slices, labels, pin, hub). Pinned to the top
  /// [wheelSize] x [wheelSize] square of the board.
  final Widget child;

  /// Text on the SPIN button (translated by the caller).
  final String spinLabel;

  /// Called when the SPIN button is tapped.
  final VoidCallback onSpinTap;

  /// True while the wheel is spinning — the studs run a chase-light.
  final bool animate;

  /// When non-null, replaces the SPIN button in the tray. Used for the
  /// "next spin in" countdown while the daily quota is used up.
  final Widget? countdown;

  const SpinWheelBoard({
    super.key,
    required this.wheelSize,
    required this.child,
    required this.spinLabel,
    required this.onSpinTap,
    this.animate = false,
    this.countdown,
  });

  // Base lip under the tray (dark indigo, top -> bottom) and its edge line.
  static Color get _panelTop => SpinWheelPurple.shade(-0.193, 0.95);
  static Color get _panelBottom => SpinWheelPurple.shade(-0.279, 1.05);
  static Color get _panelBorder => SpinWheelPurple.shade(0.031, 0.82);

  // Bright inner panel (top -> bottom), the darker side strips flanking it,
  // and the light line drawn along their edges.
  static Color get _innerTop => SpinWheelPurple.shade(-0.15, 1.3);
  static Color get _innerBottom => SpinWheelPurple.shade(-0.051, 0.93);
  static Color get _stripFill => SpinWheelPurple.shade(-0.22, 1.4);
  static Color get _edgeLine => SpinWheelPurple.shade(0.206, 1.31);

  // Geometry, as fractions of [wheelSize] (tuned against the reference art).
  static const _trayFraction = 0.38; // tray body height
  static const _trayOverlapFraction = 0.04; // tray top tucks under the wheel
  static const _baseExtraFraction = 0.07; // base lip below the tray
  static const _traySideInsetFraction = 0.012; // tray inset from board sides
  static const _trayRiseFraction = 0.13; // how far the tray's top slopes up
  static const _trayPadSideFraction = 0.024; // tray rim thickness (sides)
  static const _trayPadTopFraction = 0.03; // tray rim thickness (top)
  static const _trayPadBottomFraction = 0.04; // tray rim thickness (bottom)
  static const _contentPadSideFraction = 0.06; // studs' distance from edge
  static const _spinButtonWidthFraction = 0.4;

  @override
  Widget build(BuildContext context) {
    final trayHeight = wheelSize * _trayFraction;
    final baseExtra = wheelSize * _baseExtraFraction;
    final rise = wheelSize * _trayRiseFraction;
    final totalHeight =
        wheelSize - wheelSize * _trayOverlapFraction + trayHeight + baseExtra;
    return SizedBox(
      width: wheelSize,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Back panel + base: one silhouette, narrow at the top and
          // sweeping out to a wider base that holds the tray.
          Positioned.fill(
            child: CustomPaint(
              painter: _BoardPainter(
                wheelSize: wheelSize,
                trayTop: wheelSize - wheelSize * _trayOverlapFraction,
              ),
            ),
          ),
          // Console tray, behind the wheel. Its own top edge slopes up
          // toward the middle, so tray + slope are ONE outline.
          Positioned(
            left: wheelSize * _traySideInsetFraction,
            right: wheelSize * _traySideInsetFraction,
            bottom: baseExtra,
            height: trayHeight + rise,
            child: CustomPaint(
              painter: _TrayPainter(rise: rise),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wheelSize * _trayPadSideFraction,
                  wheelSize * _trayPadTopFraction,
                  wheelSize * _trayPadSideFraction,
                  wheelSize * _trayPadBottomFraction,
                ),
                child: CustomPaint(
                  painter: _InnerPainter(rise: rise),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      wheelSize * _contentPadSideFraction,
                      rise * 1.2, // clears the sloped top of the inner panel
                      wheelSize * _contentPadSideFraction,
                      0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StudColumn(animate: animate),
                        countdown ??
                            _SpinTrayButton(
                              label: spinLabel,
                              onTap: onSpinTap,
                              width: wheelSize * _spinButtonWidthFraction,
                            ),
                        _StudColumn(animate: animate),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Wheel drawn ON TOP of the tray's top rim (bottom of the wheel
          // rests on the tray, as in the reference).
          Positioned(top: 0, left: 0, child: child),
        ],
      ),
    );
  }
}

/// Gold 3D "SPIN" push button: dark socket, orange lip, glossy gold face.
/// The face sinks into the socket while pressed.
class _SpinTrayButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double width;

  const _SpinTrayButton({
    required this.label,
    required this.onTap,
    required this.width,
  });

  @override
  State<_SpinTrayButton> createState() => _SpinTrayButtonState();
}

class _SpinTrayButtonState extends State<_SpinTrayButton> {
  static const _faceHeight = 38.0; // gold top face
  static const _lip = 10.0; // orange edge visible under the face at rest
  static const _pressedLip = 2.0; // lip left showing while pressed
  static const _socketPad = 3.5; // dark socket showing around the face
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final depth = _pressed ? _pressedLip : _lip;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: SizedBox(
        width: widget.width,
        height: _faceHeight + _lip + _socketPad,
        child: Stack(
          children: [
            // Black socket — starts partway down the face so the face's
            // top edge stands proud of it; wraps sides and bottom only.
            Positioned(
              left: 0,
              right: 0,
              top: _faceHeight * 0.35,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SpinWheelPurple.shade(-0.422, 1.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: AppColors.spinWheelBoardRimGlow,
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              left: _socketPad,
              right: _socketPad,
              top: 0,
              bottom: _socketPad,
              child: Stack(
                children: [
                  // Orange lip (visible under the face when not pressed).
                  Positioned.fill(
                    top: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            SpinWheelGold.lipTop,
                            SpinWheelGold.lipBottom,
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 70),
                    left: 0,
                    right: 0,
                    top: _lip - depth,
                    height: _faceHeight,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            SpinWheelGold.faceTop,
                            SpinWheelGold.faceMid,
                            SpinWheelGold.faceBottom,
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: SpinWheelGold.faceEdge,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: SpinWheelGold.label,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              shadows: [
                                Shadow(
                                  color: SpinWheelGold.labelGlow,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything behind the tray and wheel:
///  - a bright inner panel (the wheel sits in front of it),
///  - a darker side strip on each flank, starting with a diagonal cut about
///    three quarters of the way down and running straight down to the tray,
///  - the dark base lip below the tray.
/// [trayTop] is the y where the tray begins.
class _BoardPainter extends CustomPainter {
  final double wheelSize;
  final double trayTop;

  const _BoardPainter({required this.wheelSize, required this.trayTop});

  @override
  void paint(Canvas canvas, Size size) {
    final w = wheelSize;
    const black = AppColors.black;

    // Base plate behind the tray (a little wider than it, so a thin rim shows
    // at the tray's sides) that also forms the lip below it. Rounded all round.
    final base = RRect.fromLTRBAndCorners(
      w * 0.008,
      trayTop,
      w - w * 0.008,
      size.height,
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: const Radius.circular(28),
      bottomRight: const Radius.circular(28),
    );
    final basePath = Path()..addRRect(base);
    canvas.drawShadow(basePath, black, 12, true);
    canvas.drawRRect(
      base,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SpinWheelBoard._panelTop, SpinWheelBoard._panelBottom],
        ).createShader(base.outerRect),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = SpinWheelBoard._panelBorder,
    );

    // Geometry (fractions of the wheel size, measured from the reference).
    final innerLeft = w * 0.043;
    final innerRight = w - innerLeft;
    final stripOuterLeft = w * 0.012; // lines up with the tray's sides
    final stripOuterRight = w - stripOuterLeft;
    final top = w * 0.013;
    final cutStart = w * 0.76; // where the diagonal cut begins (inner edge)
    final cutEnd = w * 0.82; // ...and where it reaches the strip's outer edge
    final bottom = trayTop + w * 0.1; // hidden behind the tray
    const topCorner = 30.0;

    // Side strips: diagonal cut, then straight down.
    Path strip({required bool left}) {
      final inner = left ? innerLeft : innerRight;
      final outer = left ? stripOuterLeft : stripOuterRight;
      return Path()
        ..moveTo(inner, cutStart)
        ..lineTo(outer, cutEnd)
        ..lineTo(outer, bottom)
        ..lineTo(inner, bottom)
        ..close();
    }

    final leftStrip = strip(left: true);
    final rightStrip = strip(left: false);
    for (final p in [leftStrip, rightStrip]) {
      canvas.drawShadow(p, black, 8, true);
      canvas.drawPath(p, Paint()..color = SpinWheelBoard._stripFill);
    }

    // Bright inner panel.
    final inner = Path()
      ..moveTo(innerLeft + topCorner, top)
      ..lineTo(innerRight - topCorner, top)
      ..quadraticBezierTo(innerRight, top, innerRight, top + topCorner)
      ..lineTo(innerRight, bottom)
      ..lineTo(innerLeft, bottom)
      ..lineTo(innerLeft, top + topCorner)
      ..quadraticBezierTo(innerLeft, top, innerLeft + topCorner, top)
      ..close();
    canvas.drawShadow(inner, black, 10, true);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SpinWheelBoard._innerTop, SpinWheelBoard._innerBottom],
        ).createShader(inner.getBounds()),
    );

    // Light edge lines: around the inner panel and along the strips' outer
    // edges.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..color = SpinWheelBoard._edgeLine;
    canvas.drawPath(inner, edge);
    for (final left in [true, false]) {
      final innerX = left ? innerLeft : innerRight;
      final outerX = left ? stripOuterLeft : stripOuterRight;
      canvas.drawPath(
        Path()
          ..moveTo(innerX, cutStart)
          ..lineTo(outerX, cutEnd)
          ..lineTo(outerX, bottom),
        edge,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.wheelSize != wheelSize || old.trayTop != trayTop;
}

/// Outline shared by the tray and its inset panel: small rounded top corners,
/// a top edge that slopes up to the centre by [rise], rounded bottom corners
/// of radius [bottomRadius]. [size] is the box the outline is drawn in.
Path _slopedTopPath(Size size, double rise, double bottomRadius) {
  const topCorner = 14.0;
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(0, rise + topCorner)
    ..quadraticBezierTo(0, rise, topCorner, rise - 2)
    ..lineTo(w / 2, 0)
    ..lineTo(w - topCorner, rise - 2)
    ..quadraticBezierTo(w, rise, w, rise + topCorner)
    ..lineTo(w, h - bottomRadius)
    ..quadraticBezierTo(w, h, w - bottomRadius, h)
    ..lineTo(bottomRadius, h)
    ..quadraticBezierTo(0, h, 0, h - bottomRadius)
    ..close();
}

/// Inset panel inside the tray: same sloped top as the tray, darker fill,
/// no rim or shadow. The studs and SPIN button sit on it.
class _InnerPainter extends CustomPainter {
  final double rise;

  const _InnerPainter({required this.rise});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _slopedTopPath(size, rise, 16),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpinWheelPurple.shade(0.32, 1.35),
            SpinWheelPurple.shade(-0.03, 1.0),
            SpinWheelPurple.shade(-0.18, 1.1),
          ],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_InnerPainter old) => old.rise != rise;
}

/// The console tray: sloped top, lavender-to-deep-purple gradient, thin white
/// rim, soft glow above and drop shadow below.
class _TrayPainter extends CustomPainter {
  final double rise;

  const _TrayPainter({required this.rise});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _slopedTopPath(size, rise, 22);
    // Soft lavender glow lifting off the slope onto the panel behind it.
    canvas.drawPath(
      path.shift(const Offset(0, -3)),
      Paint()
        ..color = SpinWheelPurple.shade(0.216, 1.6).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawShadow(path, AppColors.black, 6, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpinWheelPurple.shade(0.163, 1.39),
            SpinWheelPurple.shade(0.216, 1.6),
            SpinWheelPurple.shade(0.000),
          ],
          stops: [0, 0.3, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.spinWheelBoardHubShine,
    );
  }

  @override
  bool shouldRepaint(_TrayPainter old) => old.rise != rise;
}

/// Column of 3 studs. Idle: bottom one lit. Animated: the lit stud steps
/// top -> bottom in a loop with a glow, like a running light.
class _StudColumn extends StatefulWidget {
  final bool animate;

  const _StudColumn({required this.animate});

  @override
  State<_StudColumn> createState() => _StudColumnState();
}

class _StudColumnState extends State<_StudColumn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(_StudColumn old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final lit = widget.animate ? (_c.value * 3).floor().clamp(0, 2) : 2;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 5.5),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 120),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Glossy sphere: light spot up-left, deep edge down-right.
                    gradient: RadialGradient(
                      center: Alignment(-0.35, -0.4),
                      radius: 0.95,
                      colors: i == lit
                          ? [
                              SpinWheelPurple.light,
                              SpinWheelPurple.light,
                              SpinWheelPurple.light,
                            ]
                          : [
                              SpinWheelPurple.shade(0.163, 1.17),
                              SpinWheelPurple.shade(-0.025, 0.79),
                              SpinWheelPurple.shade(-0.161, 0.96),
                            ],
                      stops: const [0, 0.55, 1],
                    ),
                    boxShadow: [
                      // Small dark shadow underneath, as in the reference.
                      BoxShadow(
                        color: SpinWheelPurple.shade(
                          -0.394,
                          1.13,
                        ).withValues(alpha: 0.6),
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                      if (i == lit)
                        BoxShadow(
                          color: SpinWheelPurple.light.withValues(alpha: 0.53),
                          blurRadius: 5,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
