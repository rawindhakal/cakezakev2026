import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Mirrors [OrderCard]/[EcommerceOrderCard]'s shape (status row, item
/// thumbnails, action row) so the orders list doesn't jump layout once
/// real cards swap in.
class OrderListSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;

  const OrderListSkeletonLoader({
    super.key,
    this.itemCount = 4,
    this.shrinkWrap = false,
  });

  Widget _card(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        color: color.withValues(alpha: 0.25),
        borderRadius: AppRadius.r12,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              ShimmerBox(color, width: 90, height: 13),
              const Spacer(),
              ShimmerBox(color, width: 70, height: 22, radius: AppRadius.r16),
            ],
          ),
          AppSpacing.h8,
          ShimmerBox(color, width: 130, height: 11),
          AppSpacing.h12,
          Row(
            spacing: ThemeConstants.spaceS,
            children: [
              ShimmerBox(color, width: 48, height: 48, radius: AppRadius.r8),
              ShimmerBox(color, width: 48, height: 48, radius: AppRadius.r8),
            ],
          ),
          AppSpacing.h12,
          Row(
            spacing: ThemeConstants.spaceS,
            children: [
              Expanded(
                child: ShimmerBox(color, height: 36, radius: AppRadius.r8),
              ),
              Expanded(
                child: ShimmerBox(color, height: 36, radius: AppRadius.r8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingS,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        itemCount: itemCount,
        separatorBuilder: (_, _) => AppSpacing.h12,
        itemBuilder: (_, _) => _card(color),
      ),
    );
  }
}
