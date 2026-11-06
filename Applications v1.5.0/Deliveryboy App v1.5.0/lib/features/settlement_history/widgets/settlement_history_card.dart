import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/settlement_direction.dart';
import '../models/settlement_history_model.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'settlement_history_detail_sheet.dart';

/// Card displaying a single settlement entry — same compact layout as
/// [WalletTransactionItem]; tap opens a sheet with opening/closing balance
/// and message.
class SettlementHistoryCard extends StatelessWidget {
  final SettlementHistoryData item;

  const SettlementHistoryCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isCredit =
        SettlementDirection.fromValue(item.type) == SettlementDirection.credit;
    final accentColor = isCredit
        ? context.cs.onSecondaryContainer
        : context.cs.onErrorContainer;
    final currencySymbol = item.currency ?? '';

    return InkWell(
      onTap: () => showSettlementHistoryDetailSheet(
        context,
        item,
        currencySymbol: currencySymbol,
      ),
      borderRadius: AppRadius.r16,
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: AppDecorations.card(
          color: context.cs.surface,
          borderRadius: AppRadius.r16,
          boxShadow: [
            BoxShadow(
              color: context.cs.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceS,
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: AppText(
                    '${context.translate(LanguageLabelKeys.settlementId)} ${AppConstants.hashSymbol}${item.id ?? '—'}',
                    style: context.tt.titleSmall?.copyWith(
                      color: context.cs.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                AppText(
                  AppDateFormatter.formatDate(item.createdAt),
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Row(
              spacing: ThemeConstants.spaceS,
              children: [
                AppText(
                  '${isCredit ? '+' : '-'} $currencySymbol${item.amount ?? 0}',
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                  ),
                ),
                AppText(
                  (item.type ?? '—').capitalize,
                  style: context.tt.bodyMedium?.copyWith(color: accentColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
