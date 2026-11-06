import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Gradient card showing the delivery boy's wallet balance with a withdraw action.
class WalletBalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onWithdraw;

  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingS),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingL,
        vertical: ThemeConstants.paddingL,
      ),
      decoration: AppDecorations.card(
        color: context.cs.surface,
        borderRadius: AppRadius.r20,
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: .center,
        children: [
          Container(
            width: context.screenWidth * 0.128,
            height: context.screenWidth * 0.128,
            decoration: AppDecorations.card(
              color: context.cs.primary,
              borderRadius: AppRadius.r14,
            ),
            child: AppSvgIcon(
              AssetsConstants.walletIcon,
              color: context.cs.onPrimary,
              size: ThemeConstants.iconL,
              fit: BoxFit.scaleDown,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: ThemeConstants.spaceXS,
                children: [
                  AppText(
                    context.translate(LanguageLabelKeys.availableBalance),
                    style: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  AppText(
                    '${context.read<CountrySettingsCubit>().getCurrencySymbol()}${balance.toStringAsFixed(0)}',
                    style: context.tt.headlineMedium?.copyWith(
                      color: context.cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onWithdraw,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 22,
                vertical: ThemeConstants.paddingM,
              ),
              decoration: AppDecorations.card(
                color: context.cs.inverseSurface,
                borderRadius: AppRadius.r25,
              ),
              child: AppText(
                context.translate(LanguageLabelKeys.withdraw),
                style: context.tt.headlineLarge?.copyWith(
                  color: context.cs.onInverseSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
