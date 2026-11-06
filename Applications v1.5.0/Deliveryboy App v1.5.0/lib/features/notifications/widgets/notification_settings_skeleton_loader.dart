import 'package:deliveryboy/commons/widgets/shimmer_builder.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Mirrors `_ChannelTile`'s shape (status name + switch) so the notification
/// settings list doesn't jump layout once real tiles swap in.
class NotificationSettingsSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const NotificationSettingsSkeletonLoader({super.key, this.itemCount = 6});

  Widget _tile(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r14,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: 14,
        ),
        child: Row(
          spacing: ThemeConstants.spaceM,
          children: [
            Expanded(
              child: ShimmerBox(
                color,
                width: context.screenWidth * 0.373,
                height: context.screenHeight * 0.017,
              ),
            ),
            ShimmerBox(
              color,
              width: context.screenWidth * 0.107,
              height: context.screenHeight * 0.027,
              radius: AppRadius.r16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL),
        itemCount: itemCount,
        itemBuilder: (_, _) => _tile(context, color),
      ),
    );
  }
}
