import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/salary_model.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'salary_detail_sheet.dart';

/// Card displaying a single salary payment entry — same compact layout as
/// [WalletTransactionItem]; tap opens a sheet with the note, when present.
class SalaryCard extends StatelessWidget {
  final SalaryModel item;

  const SalaryCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final currencySymbol = item.currency ?? "";
    final hasDetail = hasSalaryDetail(item.note);

    return InkWell(
      onTap: hasDetail ? () => showSalaryDetailSheet(context, item.note) : null,
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
                    '${context.translate(LanguageLabelKeys.id)}  ${AppConstants.hashSymbol}${item.id ?? '—'}',
                    style: context.tt.titleSmall?.copyWith(
                      color: context.cs.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                AppText(
                  item.paidOn ?? '—',
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
                  '+ $currencySymbol${item.amount ?? '0'}',
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                  ),
                ),
                AppText(
                  context.translate(LanguageLabelKeys.paid),
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
