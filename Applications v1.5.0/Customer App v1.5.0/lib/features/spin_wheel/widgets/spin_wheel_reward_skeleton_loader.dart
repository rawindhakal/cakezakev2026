import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [SpinWheelRewardTile]'s shape (icon + label/amount/date lines)
/// so the rewards list doesn't jump layout once real tiles swap in.
class SpinWheelRewardSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;

  const SpinWheelRewardSkeletonLoader({
    super.key,
    this.itemCount = 8,
    this.shrinkWrap = false,
  });

  Widget _tile(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          Row(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceM,
            children: [
              ShimmerBox(color, width: 48, height: 48, radius: AppRadius.r12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXS,
                  children: [
                    ShimmerBox(color, width: double.infinity, height: 14),
                    ShimmerBox(color, width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
          ShimmerBox(
            color,
            width: double.infinity,
            height: 36,
            radius: AppRadius.r8,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ShimmerBox(color, width: 80, height: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        itemCount: itemCount,
        itemBuilder: (_, _) => _tile(context, color),
      ),
    );
  }
}
