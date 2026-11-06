import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../core/theme/app_radius.dart';
import '../../utils/extensions/context_extensions.dart';

/// Wraps [child] in an animated shimmer sweep, used for skeleton loading placeholders.
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  /// Base tone of the sweep; defaults to the theme's on-surface colour.
  final Color? color;

  const ShimmerLoading({super.key, required this.child, this.color});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.color ?? context.cs.onSurface;
    final base = tone.withValues(alpha: 0.06);
    final highlight = tone.withValues(alpha: 0.14);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 3 - 1;
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              begin: AlignmentDirectional(-1 + dx, 0),
              end: AlignmentDirectional(1 + dx, 0),
            ).createShader(bounds, textDirection: Directionality.of(context));
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Two equal-width [ShimmerBox]es side by side — the stat-tile rows that
/// repeat across the dashboard and earnings skeletons.
class ShimmerCardRow extends StatelessWidget {
  final double height;
  final double spacing;
  final BorderRadius borderRadius;

  const ShimmerCardRow({
    super.key,
    required this.height,
    this.spacing = 16,
    this.borderRadius = AppRadius.r16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: spacing,
      children: [
        Expanded(
          child: ShimmerBox(height: height, borderRadius: borderRadius),
        ),
        Expanded(
          child: ShimmerBox(height: height, borderRadius: borderRadius),
        ),
      ],
    );
  }
}

/// Solid rounded-rectangle placeholder block used inside a [ShimmerLoading].
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppRadius.r14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: AppDecorations.card(
        color: context.cs.onSurface.withValues(alpha: 0.08),
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Small shimmering square that replaces an inline spinner (buttons, icons, trailing slots).
class ShimmerInline extends StatelessWidget {
  final double size;
  final Color? color;

  const ShimmerInline({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShimmerLoading(
        color: color,
        child: ShimmerBox(
          width: size,
          height: size,
          borderRadius: AppRadius.r8,
        ),
      ),
    );
  }
}

/// Stacked shimmering text lines — mimics a paragraph of copy (policy/terms
/// pages) instead of the chunky card-row look of [ShimmerRows].
class ShimmerParagraph extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final EdgeInsetsGeometry padding;

  const ShimmerParagraph({
    super.key,
    this.lines = 10,
    this.lineHeight = 14,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    // Cycles line widths so the block reads like wrapped text, ending each
    // "paragraph" of 4 lines on a short one.
    const widthFactors = [1.0, 0.95, 1.0, 0.6];

    return ShimmerLoading(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            for (var i = 0; i < lines; i++)
              FractionallySizedBox(
                widthFactor: widthFactors[i % widthFactors.length],
                child: ShimmerBox(
                  height: lineHeight,
                  borderRadius: AppRadius.r6,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A few stacked shimmering rows for content that loads inside a sheet or screen.
class ShimmerRows extends StatelessWidget {
  final int count;
  final double rowHeight;
  final EdgeInsetsGeometry padding;

  const ShimmerRows({
    super.key,
    this.count = 4,
    this.rowHeight = 56,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            for (var i = 0; i < count; i++) ShimmerBox(height: rowHeight),
          ],
        ),
      ),
    );
  }
}
