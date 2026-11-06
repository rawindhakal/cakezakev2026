import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/models/timeline_model.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/order_status_labels.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Vertical order-status history — one dot+line per [Timeline] entry, with
/// the most recent (last) entry highlighted as the current step. Shared by
/// order detail screens (quick, ecommerce, return) so there's one timeline
/// UI everywhere.
class OrderStatusTimeline extends StatelessWidget {
  final List<Timeline> statusList;

  /// Slides and fades the entries in one after another — used when the
  /// timeline is shown inside a bottom sheet, off for the inline card preview.
  final bool animated;

  const OrderStatusTimeline({
    super.key,
    required this.statusList,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final entries = List.generate(statusList.length, (i) {
      final item = statusList[i];
      final label = (item.statusName != null && item.statusName!.isNotEmpty)
          ? item.statusName!
          : OrderStatusLabels.name(context, item.status);
      final date = item.datetime ?? '';
      final isLast = i == statusList.length - 1;
      final isDone = item.isDone ?? true;
      final dotSize = isLast ? 40.0 : 30.0;

      final row = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: .start,
          children: [
            SizedBox(
              width: context.screenWidth * 0.117,
              child: Column(
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: AppDecorations.circle(
                      color: !isDone
                          ? context.cs.onSurfaceVariant.withValues(alpha: 0.12)
                          : isLast
                          ? context.cs.primary
                          : context.cs.primary.withValues(alpha: 0.12),
                      boxShadow: isLast && isDone
                          ? [
                              BoxShadow(
                                color: context.cs.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: AppSvgIcon(
                      OrderStatusLabels.icon(item.status),
                      size: isLast ? ThemeConstants.iconL : ThemeConstants.iconS,
                      color: !isDone
                          ? context.cs.onSurfaceVariant
                          : isLast
                          ? context.cs.onPrimary
                          : context.cs.primary,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsetsDirectional.symmetric(
                          vertical: ThemeConstants.paddingXS,
                        ),
                        decoration: AppDecorations.card(
                          color: !isDone
                              ? context.cs.onSurfaceVariant.withValues(alpha: 0.2)
                              : context.cs.primary.withValues(alpha: 0.2),
                          borderRadius: AppRadius.r2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AppSpacing.w12,
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: isLast ? 0 : 20,
                  top: isLast ? 4 : 3,
                ),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    AppText(
                      label,
                      style:
                          (isLast
                                  ? context.tt.bodyMedium
                                  : context.tt.labelMedium)
                              ?.copyWith(
                                fontWeight: isLast
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: !isDone
                                    ? context.cs.onSurfaceVariant
                                    : isLast
                                    ? context.cs.primary
                                    : context.cs.onSurface,
                              ),
                    ),
                    if (date.isNotEmpty && date != 'null') ...[
                      AppSpacing.h3,
                      AppText(
                        AppDateFormatter.formatDateTime(date),
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      if (!isLast) return row;

      return Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingS,
          vertical: ThemeConstants.paddingS,
        ),
        margin: const EdgeInsetsDirectional.only(bottom: 2),
        decoration: AppDecorations.card(
          color: !isDone
              ? context.cs.onSurfaceVariant.withValues(alpha: 0.06)
              : context.cs.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.r12,
        ),
        child: row,
      );
    });

    if (!animated) return Column(children: entries);

    return SlideAnimationScope(
      builder: (context, animationController) => Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            SlideAnimation(
              position: i,
              slideDirection: SlideDirection.fromBottom,
              itemCount: entries.length,
              animationController: animationController,
              child: entries[i],
            ),
        ],
      ),
    );
  }
}
