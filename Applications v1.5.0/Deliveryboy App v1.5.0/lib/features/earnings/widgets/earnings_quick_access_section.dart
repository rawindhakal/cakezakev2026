import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import '../../home/models/dashboard_model.dart';
import 'earnings_stat_card.dart';

/// Grid of quick-access stat cards linking to wallet, cash collection, salary, and settlement.
class EarningsQuickAccessSection extends StatelessWidget {
  final Wallet? wallet;
  final Salary? salary;
  final Cash? cash;
  final double settlementHistory;
  final String currencySymbol;
  final VoidCallback onWalletTap;
  final VoidCallback onSalaryTap;
  final VoidCallback onCashCollectionTap;
  final VoidCallback onFundTransferTap;

  const EarningsQuickAccessSection({
    super.key,
    required this.wallet,
    required this.salary,
    required this.cash,
    required this.settlementHistory,
    required this.currencySymbol,
    required this.onWalletTap,
    required this.onSalaryTap,
    required this.onCashCollectionTap,
    required this.onFundTransferTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceL,
      children: [
        Row(
          spacing: ThemeConstants.spaceL,
          children: [
            EarningsStatCard(
              icon: AssetsConstants.walletIcon,
              accentColor: context.cs.primary,
              value:
                  '$currencySymbol${(wallet?.available ?? 0).toStringAsFixed(2)}',
              label: context.translate(LanguageLabelKeys.wallet),
              onTap: onWalletTap,
            ),
            EarningsStatCard(
              icon: AssetsConstants.cashCollectionIcon,
              accentColor: context.cs.primary,
              value: '$currencySymbol${(cash?.inHand ?? 0).toStringAsFixed(2)}',
              label: context.translate(LanguageLabelKeys.cashCollection),
              onTap: onCashCollectionTap,
            ),
          ],
        ),
        Row(
          spacing: ThemeConstants.spaceL,
          children: [
            EarningsStatCard(
              icon: AssetsConstants.salaryIcon,
              accentColor: context.cs.primary,
              value:
                  '$currencySymbol${(salary?.totalPaid ?? 0).toStringAsFixed(2)}',
              label: context.translate(LanguageLabelKeys.salary),
              onTap: onSalaryTap,
            ),
            EarningsStatCard(
              icon: AssetsConstants.settlementHistoryIcon,
              accentColor: context.cs.primary,
              value: '$currencySymbol$settlementHistory',
              label: context.translate(LanguageLabelKeys.settlementHistory),
              onTap: onFundTransferTap,
            ),
          ],
        ),
      ],
    );
  }
}
