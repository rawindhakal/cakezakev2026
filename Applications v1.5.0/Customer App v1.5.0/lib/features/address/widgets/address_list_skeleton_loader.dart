import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [AddressCard]'s shape (icon box, type/badge row, address lines,
/// phone row) so address list doesn't jump layout once real cards swap in.
class AddressListSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;

  const AddressListSkeletonLoader({
    super.key,
    this.itemCount = 4,
    this.shrinkWrap = false,
  });

  Widget _card(BuildContext context, Color color) {
    return Container(
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        child: Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceM,
          children: [
            ShimmerBox(color, width: 40, height: 40, radius: AppRadius.r8),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceS,
                children: [
                  Row(
                    spacing: ThemeConstants.spaceS,
                    children: [
                      ShimmerBox(color, width: 60, height: 14),
                      ShimmerBox(
                        color,
                        width: 50,
                        height: 16,
                        radius: AppRadius.r20,
                      ),
                    ],
                  ),
                  ShimmerBox(color, width: double.infinity, height: 12),
                  ShimmerBox(color, width: 180, height: 12),
                  ShimmerBox(color, width: 120, height: 12),
                ],
              ),
            ),
            ShimmerBox(color, width: 20, height: 20, radius: AppRadius.r4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        itemCount: itemCount,
        separatorBuilder: (_, _) => AppSpacing.h10,
        itemBuilder: (_, _) => _card(context, color),
      ),
    );
  }
}
