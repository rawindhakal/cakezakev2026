import 'package:flutter/material.dart';

/// Skeuomorphic "3D" press button — a raised block with a solid-color side
/// (bottom shadow) that the button sinks into on tap, giving a physical
/// push-down feel. Use for standalone celebratory/CTA actions (e.g. spin
/// wheel "Continue Shopping") where the flat [AppButton] look is too plain.
class AppButton3D extends StatefulWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback? onPressed;
  final double height;
  final double depth;
  final BorderRadius borderRadius;
  final double? width;

  const AppButton3D({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    required this.onPressed,
    this.height = 52,
    this.depth = 6,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.width,
  });

  @override
  State<AppButton3D> createState() => _AppButton3DState();
}

class _AppButton3DState extends State<AppButton3D> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.color);
    final sideColor = hsl
        .withLightness((hsl.lightness * 0.65).clamp(0.0, 1.0))
        .toColor();
    final topColor = Color.lerp(widget.color, Colors.white, 0.18)!;
    final disabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled
          ? null
          : (_) {
              _setPressed(false);
              widget.onPressed?.call();
            },
      onTapCancel: disabled ? null : () => _setPressed(false),
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height + widget.depth,
        child: Stack(
          children: [
            Positioned.fill(
              top: widget.depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: disabled
                      ? sideColor.withValues(alpha: 0.5)
                      : sideColor,
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              curve: Curves.easeOut,
              top: _pressed ? widget.depth : 0,
              left: 0,
              right: 0,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      topColor.withValues(alpha: disabled ? 0.5 : 1),
                      widget.color.withValues(alpha: disabled ? 0.5 : 1),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: widget.textColor ?? Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
