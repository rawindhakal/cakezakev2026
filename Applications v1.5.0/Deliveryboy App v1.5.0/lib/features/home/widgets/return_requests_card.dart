import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/dashboard_model.dart';
import 'dashboard_stat_column.dart';
import 'return_requests_pie_chart.dart';

/// "Returns & Requests" card: donut breakdown by status (tap a slice for name
/// + count) plus completed/pending summary rows, all in one card.
class ReturnRequestsCard extends StatelessWidget {
  final Returns returns;

  const ReturnRequestsCard({super.key, required this.returns});

  @override
  Widget build(BuildContext context) {
    final breakdown = returns.breakdown ?? [];

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.returnsAndRequests),
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
              if (breakdown.isNotEmpty) ...[
                ReturnRequestsPieChart(
                  breakdown: breakdown,
                  total: returns.total ?? 0,
                ),
                AppSpacing.h12,
                Divider(height: 1, color: context.cs.outlineVariant),
                AppSpacing.h12,
              ] else ...[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          context.translate(LanguageLabelKeys.returnRequests),
                          style: context.tt.bodyMedium?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AppText(
                        '${returns.total ?? 0}',
                        style: context.tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.h4,
              ],
              Row(
                children: [
                  Expanded(
                    child: DashboardStatColumn(
                      label: context.translate(LanguageLabelKeys.completed),
                      value: '${returns.completed ?? 0}',
                    ),
                  ),
                  Expanded(
                    child: DashboardStatColumn(
                      label: context.translate(LanguageLabelKeys.pending),
                      value: '${returns.pending ?? 0}',
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
