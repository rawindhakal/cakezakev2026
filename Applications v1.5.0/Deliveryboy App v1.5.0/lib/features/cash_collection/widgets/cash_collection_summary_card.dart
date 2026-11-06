import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/cash_collection_cubit.dart';
import '../../../core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/sticky_bar.dart';

/// Summary card showing cash-in-hand and total cash-collected totals.
class CashCollectionSummaryCard extends StatelessWidget {
  const CashCollectionSummaryCard({super.key});

  static String format(dynamic amount) {
    if (amount == null) return '0';
    if (amount is String) {
      if (amount.isEmpty || amount == 'null') return '0';
      return double.tryParse(amount)?.toStringAsFixed(2) ?? '0';
    }
    if (amount is num) return amount.toStringAsFixed(2);
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CashCollectionCubit, CashCollectionState>(
      builder: (context, state) {
        final cubit = context.read<CashCollectionCubit>();
        final sym = context.read<CountrySettingsCubit>().getCurrencySymbol();
        final inHand = state is CashCollectionLoaded
            ? format(cubit.cashInHand)
            : '—';
        final collected = state is CashCollectionLoaded
            ? format(cubit.cashCollected)
            : '—';
        return Container(
          margin: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, ThemeConstants.paddingM),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
            vertical: 14,
          ),
          decoration: AppDecorations.card(
            color: context.cs.surface,
            borderRadius: AppRadius.r14,
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: context.translate(LanguageLabelKeys.cashInHand),
                  amount: '$sym$inHand',
                  icon: AssetsConstants.cashCollectionIcon,
                  color: context.cs.primary,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: context.cs.outlineVariant,
                margin: const EdgeInsetsDirectional.only(end: 10),
              ),
              Expanded(
                child: _StatItem(
                  label: context.translate(LanguageLabelKeys.cashCollected),
                  amount: '$sym$collected',
                  icon: AssetsConstants.walletIcon,
                  color: context.cs.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact cash-in-hand / cash-collected bar docked under the app bar once
/// [CashCollectionSummaryCard] has scrolled out of view.
class CashCollectionStickyBar extends StatelessWidget {
  final ScrollController controller;

  const CashCollectionStickyBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CashCollectionCubit, CashCollectionState>(
      builder: (context, state) {
        final cubit = context.read<CashCollectionCubit>();
        final sym = context.read<CountrySettingsCubit>().getCurrencySymbol();
        final loaded = state is CashCollectionLoaded;
        return StickyBar(
          controller: controller,
          label: '',
          hidden: !loaded,
          content: Row(
            children: [
              Expanded(
                child: _StickyStat(
                  icon: AssetsConstants.cashCollectionIcon,
                  label: context.translate(LanguageLabelKeys.cashInHand),
                  amount: '$sym${CashCollectionSummaryCard.format(cubit.cashInHand)}',
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: context.cs.outlineVariant,
                margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
              ),
              Expanded(
                child: _StickyStat(
                  icon: AssetsConstants.walletIcon,
                  label: context.translate(LanguageLabelKeys.cashCollected),
                  amount: '$sym${CashCollectionSummaryCard.format(cubit.cashCollected)}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StickyStat extends StatelessWidget {
  final String icon;
  final String label;
  final String amount;

  const _StickyStat({
    required this.icon,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: ThemeConstants.spaceS,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: AppDecorations.card(
            color: context.cs.primary,
            borderRadius: AppRadius.r8,
          ),
          child: AppSvgIcon(
            icon,
            color: context.cs.onPrimary,
            size: ThemeConstants.iconS,
            fit: BoxFit.scaleDown,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                label,
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppText(
                amount,
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String amount;
  final String icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: ThemeConstants.spaceM,
      children: [
        Container(
          width: context.screenWidth * 0.101,
          height: context.screenWidth * 0.101,
          padding: const EdgeInsetsDirectional.all(9),
          decoration: AppDecorations.card(
            color: color,
            borderRadius: AppRadius.r10,
          ),
          child: AppSvgIcon(
            icon,
            color: context.cs.onPrimary,
            size: ThemeConstants.iconS,
            fit: BoxFit.scaleDown,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXS,
            children: [
              AppText(
                label,
                style: context.tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
              AppText(
                amount,
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
