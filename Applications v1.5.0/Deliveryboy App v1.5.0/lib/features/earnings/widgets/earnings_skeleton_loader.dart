import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Shimmering placeholder mirroring the earnings screen layout
/// (summary card + quick-access stat tiles) while dashboard data is loading.
class EarningsSkeletonLoader extends StatelessWidget {
  const EarningsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          // Total / today earning summary card
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, 0),
            child: ShimmerBox(height: context.screenHeight * 0.185, borderRadius: AppRadius.r20),
          ),
          AppSpacing.h20,

          // Wallet / cash / salary / settlement quick-access tiles
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: ThemeConstants.paddingL),
            child: Column(
              children: [
                ShimmerCardRow(height: context.screenHeight * 0.133),
                AppSpacing.h16,
                ShimmerCardRow(height: context.screenHeight * 0.133),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
