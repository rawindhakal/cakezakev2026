import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Stacked shimmering text lines — mirrors a paragraph of policy/terms copy
/// instead of a generic card-row skeleton, so the loading state doesn't jump
/// layout once the real HTML content swaps in.
class PolicyContentSkeletonLoader extends StatelessWidget {
  final int lines;

  const PolicyContentSkeletonLoader({super.key, this.lines = 12});

  // Cycles line widths so the block reads like wrapped text, ending each
  // "paragraph" of 4 lines on a short one.
  static const _widthFactors = [1.0, 0.95, 1.0, 0.6];

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingS,
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            for (var i = 0; i < lines; i++) ...[
              FractionallySizedBox(
                widthFactor: _widthFactors[i % _widthFactors.length],
                child: ShimmerBox(color, height: 14),
              ),
              if (i != lines - 1) AppSpacing.h10,
            ],
          ],
        ),
      ),
    );
  }
}
