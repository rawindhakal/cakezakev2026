import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Flat card showing total earning with today's earning as a secondary stat.
class EarningsSummaryCard extends StatelessWidget {
  final double totalEarning;
  final double todayEarning;
  final String currencySymbol;

  const EarningsSummaryCard({
    super.key,
    required this.totalEarning,
    required this.todayEarning,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, 0),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      decoration: AppDecorations.card(
        color: context.cs.surface,
        borderRadius: AppRadius.r20,
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceL,
        children: [
          Row(
            crossAxisAlignment: .center,
            spacing: ThemeConstants.spaceM,
            children: [
              Container(
                width: context.screenWidth * 0.117,
                height: context.screenWidth * 0.117,
                decoration: AppDecorations.card(
                  color: context.cs.primary,
                  borderRadius: AppRadius.r14,
                ),
                child: AppSvgIcon(
                  AssetsConstants.earingIcon,
                  color: context.cs.onPrimary,
                  size: ThemeConstants.iconM,
                  fit: BoxFit.scaleDown,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXXS,
                  children: [
                    AppText(
                      context.translate(LanguageLabelKeys.totalEarning),
                      style: context.tt.bodyMedium?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    AppText(
                      '$currencySymbol${totalEarning.toStringAsFixed(2)}',
                      style: context.tt.headlineMedium?.copyWith(
                        color: context.cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
            height: 1,
            color: context.cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Row(
            spacing: ThemeConstants.spaceS,
            children: [
              AppSvgIcon(
                AssetsConstants.dateIcon,
                color: context.cs.onSurfaceVariant,
                size: ThemeConstants.iconL,
              ),
              AppText(
                context.translate(LanguageLabelKeys.todayEarning),
                style: context.tt.bodyMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              AppText(
                '$currencySymbol${todayEarning.toStringAsFixed(2)}',
                style: context.tt.titleSmall?.copyWith(
                  color: context.cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
