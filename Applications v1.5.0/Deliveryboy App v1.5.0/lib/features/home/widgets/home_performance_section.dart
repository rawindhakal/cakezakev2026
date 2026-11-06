import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/dashboard_model.dart';
import '../../../core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import '../../earnings/widgets/earnings_stat_card.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Section showing today's summary metrics on the home dashboard.
class HomePerformanceSection extends StatelessWidget {
  final DashboardModel dashboard;

  const HomePerformanceSection({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final symbol = context.read<CountrySettingsCubit>().getCurrencySymbol();

    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            AppText(
              context.translate(LanguageLabelKeys.todaysPerformance),
              style: context.tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: AppDecorations.card(
                color: context.cs.primaryContainer,
                borderRadius: AppRadius.r20,
              ),
              child: AppText(
                AppDateFormatter.formatDate(DateTime.now()),
                style: context.tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.primary,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.h16,
        Row(
          spacing: ThemeConstants.spaceL,
          children: [
            EarningsStatCard(
              icon: AssetsConstants.walletIcon,
              accentColor: context.cs.primary,
              value: '$symbol${dashboard.data?.today?.earnings ?? 0}',
              label: context.translate(LanguageLabelKeys.todaysEarnings),
            ),
            EarningsStatCard(
              icon: AssetsConstants.orderIcon,
              accentColor: context.cs.primary,
              value: '${dashboard.data?.today?.delivered ?? 0}',
              label: context.translate(LanguageLabelKeys.ordersDelivered),
            ),
          ],
        ),
        AppSpacing.h16,
        Row(
          spacing: ThemeConstants.spaceL,
          children: [
            EarningsStatCard(
              icon: AssetsConstants.cashCollectionIcon,
              accentColor: context.cs.primary,
              value: '$symbol${dashboard.data?.today?.cash ?? 0}',
              label: context.translate(LanguageLabelKeys.cashCollected),
            ),
            EarningsStatCard(
              icon: AssetsConstants.orderIcon,
              accentColor: context.cs.primary,
              value: '${dashboard.data?.today?.orders ?? 0}',
              label: context.translate(LanguageLabelKeys.todaysOrders),
            ),
          ],
        ),
      ],
    );
  }
}
