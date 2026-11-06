import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Vertical order-status history — one dot+line per [Timeline] entry, with
/// the most recent (last) entry highlighted as the current step. Shared by
/// order listing cards and order-detail screens (quick + ecommerce), and by
/// the tracking bottom sheet, so there's one timeline UI everywhere.
class OrderStatusTimeline extends StatelessWidget {
  final List<Timeline> statusList;
  final bool isDark;

  const OrderStatusTimeline({
    super.key,
    required this.statusList,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(statusList.length, (i) {
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
            spacing: ThemeConstants.spaceM,
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: AppDecorations.box(
                        color: !isDone
                            ? context.cs.onSurfaceVariant.withValues(
                                alpha: 0.12,
                              )
                            : isLast
                            ? context.cs.primary
                            : context.cs.primary.withValues(alpha: 0.12),
                        shape: .circle,
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
                        size: isLast
                            ? ThemeConstants.iconL
                            : ThemeConstants.iconS,
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
                          decoration: AppDecorations.box(
                            color: !isDone
                                ? context.cs.onSurfaceVariant.withValues(
                                    alpha: 0.2,
                                  )
                                : context.cs.primary.withValues(alpha: 0.2),
                            borderRadius: AppRadius.r2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    bottom: isLast ? 0 : ThemeConstants.paddingXL,
                    top: isLast
                        ? ThemeConstants.paddingXS
                        : ThemeConstants.paddingXS,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      AppText(
                        label,
                        style:
                            (isLast
                                    ? context.tt.bodyMedium
                                    : context.tt.bodySmall)
                                ?.copyWith(
                                  fontSize: isLast ? 15 : 13,
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
                      if (date.hasValue) ...[
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
          margin: const EdgeInsetsDirectional.only(
            bottom: ThemeConstants.paddingXS,
          ),
          decoration: AppDecorations.box(
            color: !isDone
                ? context.cs.onSurfaceVariant.withValues(alpha: 0.06)
                : context.cs.primary.withValues(alpha: 0.06),
            borderRadius: AppRadius.r12,
          ),
          child: row,
        );
      }),
    );
  }
}
