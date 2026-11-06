import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Drives the pulsing color-lerp animation shared by every skeleton loader
/// in the app — owns the [AnimationController] lifecycle so individual
/// skeletons only need to describe their box layout via [builder].
class ShimmerBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, Color color) builder;

  const ShimmerBuilder({super.key, required this.builder});

  @override
  State<ShimmerBuilder> createState() => _ShimmerBuilderState();
}

class _ShimmerBuilderState extends State<ShimmerBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = context.cs.surfaceContainerHighest;
    final highlightColor = context.cs.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(baseColor, highlightColor, _controller.value)!;
        return widget.builder(context, color);
      },
    );
  }
}

/// A single shimmering rect — the repeated placeholder block skeleton
/// layouts are built from.
class ShimmerBox extends StatelessWidget {
  final Color color;
  final double? width;
  final double height;
  final BorderRadiusGeometry? radius;

  const ShimmerBox(
    this.color, {
    super.key,
    this.width,
    this.height = 14,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: AppDecorations.box(
        color: color,
        borderRadius: radius ?? AppRadius.r4,
      ),
    );
  }
}
