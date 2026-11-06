import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Shimmering placeholder that mirrors the home dashboard layout
/// (performance tiles, overview tiles, status grid, trend and rate cards)
/// while [DashboardCubit] is loading.
class DashboardSkeletonLoader extends StatelessWidget {
  const DashboardSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingXL, ThemeConstants.paddingL, 0),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // Today's performance — section title + date chip
            Row(
              children: [
                ShimmerBox(width: context.screenWidth * 0.4, height: context.screenHeight * 0.02, borderRadius: AppRadius.r8),
                const Spacer(),
                ShimmerBox(width: context.screenWidth * 0.224, height: context.screenHeight * 0.03, borderRadius: AppRadius.r20),
              ],
            ),
            AppSpacing.h16,
            ShimmerCardRow(height: context.screenHeight * 0.133),
            AppSpacing.h16,
            ShimmerCardRow(height: context.screenHeight * 0.133),
            AppSpacing.h16,

            // Delivery overview — stat tiles
            ShimmerBox(
              width: context.screenWidth * 0.373,
              height: context.screenHeight * 0.02,
              borderRadius: AppRadius.r8,
            ),
            AppSpacing.h12,
            ShimmerCardRow(height: context.screenHeight * 0.086, spacing: ThemeConstants.spaceM),
            AppSpacing.h12,
            ShimmerCardRow(height: context.screenHeight * 0.086, spacing: ThemeConstants.spaceM),
            AppSpacing.h14,

            // Active orders status grid
            ShimmerBox(height: context.screenHeight * 0.209, borderRadius: AppRadius.r16),
            AppSpacing.h14,

            // Earnings trend card
            ShimmerBox(height: context.screenHeight * 0.259, borderRadius: AppRadius.r16),
            AppSpacing.h14,

            // Delivery performance card
            ShimmerBox(
              width: context.screenWidth * 0.427,
              height: context.screenHeight * 0.02,
              borderRadius: AppRadius.r8,
            ),
            AppSpacing.h10,
            ShimmerBox(height: context.screenHeight * 0.246, borderRadius: AppRadius.r16),
            AppSpacing.h90,
          ],
        ),
      ),
    );
  }
}
