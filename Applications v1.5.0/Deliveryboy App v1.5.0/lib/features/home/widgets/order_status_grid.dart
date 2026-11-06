import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../commons/widgets/app_text.dart';
import '../models/dashboard_model.dart';
import 'active_status_chart.dart';
import 'dashboard_stat_column.dart';

/// "Active Orders" card: order-status rows (Out for Pickup, Delivered, ...)
/// separated from the order-type breakdown (Quick / Ecommerce), since a
/// quick/ecommerce order can be in any of those statuses — the two are
/// different dimensions, not additional statuses to sum.
class OrderStatusGrid extends StatelessWidget {
  final List<StatusBreakdown> statuses;
  final int completed;
  final int quick;
  final int ecommerce;

  const OrderStatusGrid({
    super.key,
    required this.statuses,
    this.completed = 0,
    this.quick = 0,
    this.ecommerce = 0,
  });

  @override
  Widget build(BuildContext context) {
    final statusRows = statuses.isNotEmpty
        ? [
            for (final status in statuses)
              MapEntry(status.name ?? '', status.count ?? 0),
          ]
        : [MapEntry(context.translate(LanguageLabelKeys.completed), completed)];

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.activeOrders),
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
          decoration: AppDecorations.card(
            color: context.cs.surface,
            borderRadius: AppRadius.r16,
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              ActiveStatusChart(items: statusRows),
              AppSpacing.h8,
              Divider(height: 1, color: context.cs.outlineVariant),
              AppSpacing.h10,
              Row(
                children: [
                  Expanded(
                    child: DashboardStatColumn(
                      label: context.translate(LanguageLabelKeys.quickOrders),
                      value: '$quick',
                    ),
                  ),
                  Expanded(
                    child: DashboardStatColumn(
                      label: context.translate(
                        LanguageLabelKeys.ecommerceOrders,
                      ),
                      value: '$ecommerce',
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
