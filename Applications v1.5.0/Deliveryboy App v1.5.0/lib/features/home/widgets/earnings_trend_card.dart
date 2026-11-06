import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/dashboard_model.dart';
import '../../../core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'earnings_line_chart.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Maps a period label key to the API's `trend` query value.
String trendValueForPeriod(String periodKey) {
  switch (periodKey) {
    case LanguageLabelKeys.last30Days:
      return '30';
    case LanguageLabelKeys.last90Days:
      return '90';
    case LanguageLabelKeys.last12Months:
      return '12m';
    case LanguageLabelKeys.last7Days:
    default:
      return '7';
  }
}

/// Card showing the earnings trend with a line chart and a period filter.
/// The selected period is owned by the parent (it must survive the
/// dashboard's loading-state rebuild that happens on every refetch).
class EarningsTrendCard extends StatelessWidget {
  final EarningsTrend trend;
  final String currencySymbol;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const EarningsTrendCard({
    super.key,
    required this.trend,
    required this.currencySymbol,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final values = trend.data ?? [];
    final labels = trend.labels ?? [];
    final isUp = trend.trend?.toLowerCase() == 'up';

    final periods = [
      LanguageLabelKeys.last7Days,
      LanguageLabelKeys.last30Days,
      LanguageLabelKeys.last90Days,
      LanguageLabelKeys.last12Months,
    ];

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.last30DaysEarnings),
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
              Row(
                crossAxisAlignment: .center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: .end,
                      spacing: ThemeConstants.spaceS,
                      children: [
                        AppText(
                          '$currencySymbol${trend.total ?? 0}',
                          style: context.tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.cs.onSurface,
                          ),
                        ),
                        AppSvgIcon(
                          isUp
                              ? AssetsConstants.trendingUpIcon
                              : AssetsConstants.trendingDownIcon,
                          color: isUp
                              ? context.cs.onSecondaryContainer
                              : context.cs.error,
                          size: ThemeConstants.iconM,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: selectedPeriod,
                    onSelected: onPeriodChanged,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
                    itemBuilder: (context) => [
                      for (final period in periods)
                        PopupMenuItem(
                          value: period,
                          child: AppText(context.translate(period)),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingS,
                      ),
                      decoration: AppDecorations.card(
                        borderRadius: AppRadius.r20,
                        border: Border.all(
                          color: context.cs.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: ThemeConstants.spaceS,
                        children: [
                          AppText(
                            context.translate(selectedPeriod),
                            style: context.tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.cs.primary,
                            ),
                          ),
                          AppSvgIcon(
                            AssetsConstants.arrowDownIcon,
                            size: ThemeConstants.iconS,
                            color: context.cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.h16,
              if (values.isEmpty)
                SizedBox(
                  height: context.screenHeight * 0.172,
                  child: Center(
                    child: AppText(
                      '-',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                EarningsLineChart(values: values),
              if (labels.isNotEmpty) ...[
                AppSpacing.h8,
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 36),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      AppText(
                        labels.first,
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      AppText(
                        labels.last,
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
