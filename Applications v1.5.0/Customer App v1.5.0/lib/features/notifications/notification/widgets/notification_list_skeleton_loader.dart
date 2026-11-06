import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors `_NotificationCard`'s shape (icon box, title, message, time row)
/// so the notifications list doesn't jump layout once real cards swap in.
class NotificationListSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;

  const NotificationListSkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.shrinkWrap = false,
  });

  Widget _card(BuildContext context, Color color) {
    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                ShimmerBox(color, width: 140, height: 15),
                AppSpacing.h6,
                ShimmerBox(color, width: double.infinity, height: 12),
                AppSpacing.h4,
                ShimmerBox(color, width: 160, height: 12),
                AppSpacing.h8,
                ShimmerBox(color, width: 80, height: 11),
              ],
            ),
          ),
          ShimmerBox(color, width: 44, height: 44, radius: AppRadius.r10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.separated(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: ThemeConstants.paddingM,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        itemCount: itemCount,
        separatorBuilder: (_, _) => AppSpacing.h8,
        itemBuilder: (_, _) => _card(context, color),
      ),
    );
  }
}
