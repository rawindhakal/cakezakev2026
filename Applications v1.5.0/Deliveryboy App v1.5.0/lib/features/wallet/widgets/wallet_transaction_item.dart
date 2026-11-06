import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import '../models/withdrawal_status.dart';
import 'wallet_transaction_detail_sheet.dart';

/// Card displaying a single wallet withdrawal transaction with status and message.
/// Tapping opens a detail sheet with the message/remark, when either is present.
class WalletTransactionItem extends StatelessWidget {
  final dynamic transaction;
  const WalletTransactionItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusText) = _statusMeta(context, transaction.status);
    final currencySymbol = transaction.currency ?? "";
    final String? message = transaction.message;
    final String? remark = transaction.remark;
    final hasDetail = hasWalletTransactionDetail(
      message: message,
      remark: remark,
    );

    return InkWell(
      onTap: hasDetail
          ? () => showWalletTransactionDetailSheet(
              context,
              message: message,
              remark: remark,
            )
          : null,
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
                    '${context.translate(LanguageLabelKeys.requestId)} ${AppConstants.hashSymbol}${transaction.id}',
                    style: context.tt.titleSmall?.copyWith(
                      color: context.cs.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                AppText(
                  AppDateFormatter.formatDate(transaction.createdAt),
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
                  '$currencySymbol${transaction.amount ?? '0'}',
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                  ),
                ),
                AppText(
                  statusText,
                  style: context.tt.bodyMedium?.copyWith(color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusMeta(BuildContext context, String? status) =>
      switch (WithdrawalStatus.fromValue(status)) {
        WithdrawalStatus.pending => (
          context.cs.errorContainer,
          context.translate(LanguageLabelKeys.pending),
        ),
        WithdrawalStatus.approved => (
          context.cs.onSecondaryContainer,
          context.translate(LanguageLabelKeys.approved),
        ),
        WithdrawalStatus.rejected => (
          context.cs.error,
          context.translate(LanguageLabelKeys.rejected),
        ),
        WithdrawalStatus.all => (
          context.cs.onSurfaceVariant,
          context.translate(LanguageLabelKeys.statusUnknown),
        ),
      };
}
