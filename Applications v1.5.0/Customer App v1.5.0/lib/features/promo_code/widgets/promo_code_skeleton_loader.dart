import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [PromoCodeTileWidget]'s shape (icon + title/code + button,
/// divider, bullet notes) so the list doesn't jump layout once real
/// tiles swap in.
class PromoCodeSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const PromoCodeSkeletonLoader({super.key, this.itemCount = 5});

  Widget _tile(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: .center,
            children: [
              ShimmerBox(color, width: 40, height: 40, radius: AppRadius.r10),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceS,
                  children: [
                    ShimmerBox(color, width: 140, height: 15),
                    ShimmerBox(color, width: 100, height: 12),
                  ],
                ),
              ),
              AppSpacing.w10,
              ShimmerBox(color, width: 70, height: 30, radius: AppRadius.r8),
            ],
          ),
          AppSpacing.h12,
          ShimmerBox(color, height: 1),
          AppSpacing.h10,
          ShimmerBox(color, width: double.infinity, height: 11),
          AppSpacing.h6,
          ShimmerBox(color, width: 180, height: 11),
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
          0,
          ThemeConstants.paddingL,
          ThemeConstants.paddingXXL,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, index) => _tile(context, color),
      ),
    );
  }
}
