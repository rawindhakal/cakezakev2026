import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/dashboard_model.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'dashboard_list_card.dart';
import 'dashboard_stat_card.dart';
import 'earnings_trend_card.dart';
import 'order_status_grid.dart';
import 'return_requests_card.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Section showing today's order/wallet overview tiles, rate bars, and status breakdown.
class HomeOverviewSection extends StatelessWidget {
  final DashboardModel dashboard;
  final String earningsPeriod;
  final ValueChanged<String> onEarningsPeriodChanged;

  const HomeOverviewSection({
    super.key,
    required this.dashboard,
    required this.earningsPeriod,
    required this.onEarningsPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = context.read<CountrySettingsCubit>().getCurrencySymbol();
    final orders = dashboard.data?.orders;
    final quick = orders?.quick ?? 0;
    final ecommerce = orders?.ecommerce ?? 0;
    final statuses = (dashboard.data?.statusBreakdown ?? [])
        .where((s) => s.statusId != 7)
        .toList();

    return Column(
      crossAxisAlignment: .start,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.deliveryOverview),
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
        AppSpacing.h12,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            spacing: ThemeConstants.spaceM,
            children: [
              DashboardStatCard(
                icon: AssetsConstants.orderIcon,
                label: context.translate(LanguageLabelKeys.activeOrders),
                value: '${orders?.active ?? 0}',
              ),
              DashboardStatCard(
                icon: AssetsConstants.walletIcon,
                label: context.translate(LanguageLabelKeys.availableBalance),
                value: '$symbol${dashboard.data?.wallet?.available ?? 0}',
                onTap: () => AppNavigator.pushNamed(context, RouteNames.wallet),
              ),
            ],
          ),
        ),
        AppSpacing.h12,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            spacing: ThemeConstants.spaceM,
            children: [
              DashboardStatCard(
                icon: AssetsConstants.cashCollectionIcon,
                label: context.translate(LanguageLabelKeys.cashInHand),
                value: '$symbol${(dashboard.data?.cash?.inHand ?? 0).toInt()}',
                onTap: () =>
                    AppNavigator.pushNamed(context, RouteNames.cashCollection),
              ),
              DashboardStatCard(
                icon: AssetsConstants.orderIcon,
                label: context.translate(LanguageLabelKeys.totalOrders),
                value: '${orders?.total ?? 0}',
              ),
            ],
          ),
        ),
        AppSpacing.h14,
        OrderStatusGrid(
          statuses: statuses,
          completed: orders?.delivered ?? 0,
          quick: quick,
          ecommerce: ecommerce,
        ),
        if (dashboard.data?.returns != null) ...[
          AppSpacing.h14,
          ReturnRequestsCard(returns: dashboard.data!.returns!),
        ],
        if (dashboard.data?.earningsTrend != null) ...[
          AppSpacing.h14,
          EarningsTrendCard(
            trend: dashboard.data!.earningsTrend!,
            currencySymbol: symbol,
            selectedPeriod: earningsPeriod,
            onPeriodChanged: onEarningsPeriodChanged,
          ),
        ],
        AppSpacing.h14,
        AppText(
          context.translate(LanguageLabelKeys.deliveryPerformance),
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
        AppSpacing.h10,
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
                mainAxisAlignment: .spaceBetween,
                crossAxisAlignment: .start,
                children: [
                  for (final item in [
                    MapEntry(
                      context.translate(LanguageLabelKeys.total),
                      orders?.total ?? 0,
                    ),
                    MapEntry(
                      context.translate(LanguageLabelKeys.active),
                      orders?.active ?? 0,
                    ),
                    MapEntry(
                      context.translate(LanguageLabelKeys.delivered),
                      orders?.delivered ?? 0,
                    ),
                    MapEntry(
                      context.translate(LanguageLabelKeys.cancelled),
                      orders?.cancelled ?? 0,
                    ),
                  ])
                    Column(
                      crossAxisAlignment: .center,
                      spacing: ThemeConstants.spaceXS,
                      children: [
                        AppText(
                          item.key,
                          style: context.tt.bodyMedium?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                        AppText(
                          '${item.value}',
                          style: context.tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              AppSpacing.h16,
              Divider(height: 1, color: context.cs.outlineVariant),
              AppSpacing.h4,
              for (final row in [
                DashboardListRow(
                  label: context.translate(
                    LanguageLabelKeys.deliverySuccessRate,
                  ),
                  value:
                      '${((orders?.total ?? 0) == 0 ? 0 : ((orders!.delivered ?? 0) / orders.total!) * 100).toStringAsFixed(0)}%',
                  percent: (orders?.total ?? 0) == 0
                      ? 0
                      : (orders!.delivered ?? 0) / orders.total!,
                ),
                DashboardListRow(
                  label: context.translate(LanguageLabelKeys.cancellationRate),
                  value:
                      '${((orders?.total ?? 0) == 0 ? 0 : ((orders!.cancelled ?? 0) / orders.total!) * 100).toStringAsFixed(0)}%',
                  percent: (orders?.total ?? 0) == 0
                      ? 0
                      : (orders!.cancelled ?? 0) / orders.total!,
                ),
                DashboardListRow(
                  label: context.translate(LanguageLabelKeys.inProgress),
                  value:
                      '${((orders?.total ?? 0) == 0 ? 0 : ((orders!.active ?? 0) / orders.total!) * 100).toStringAsFixed(0)}%',
                  percent: (orders?.total ?? 0) == 0
                      ? 0
                      : (orders!.active ?? 0) / orders.total!,
                ),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceS,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              row.label,
                              style: context.tt.bodyMedium?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          AppText(
                            row.value,
                            style: context.tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (row.percent != null)
                        ClipRRect(
                          borderRadius: AppRadius.r20,
                          child: LinearProgressIndicator(
                            value: row.percent!.clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: context.cs.primary.withValues(
                              alpha: 0.12,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.cs.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
