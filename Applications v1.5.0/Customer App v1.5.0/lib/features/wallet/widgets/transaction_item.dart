import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/wallet/models/transaction_model.dart';
import 'package:customer/features/wallet/models/transaction_status.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class TransactionItem extends StatelessWidget {
  final TransactionData txn;
  const TransactionItem({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final currencySymbol = txn.currency;
    final paymentMeta = _paymentMeta(context, txn.type);
    final statusMeta = _statusMeta(context, txn.status);
    final amountColor = statusMeta.$1;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingS),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceM,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: AppDecorations.box(
                    color: context.cs.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: AppRadius.r8,
                  ),
                  alignment: Alignment.center,
                  child: AppSvgIcon(paymentMeta.$2, size: ThemeConstants.iconM),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceXXS,
                    children: [
                      AppText(
                        paymentMeta.$1,
                        style: context.tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                      AppText(
                        '${context.translate(LanguageLabelKeys.txnId)}:${txn.txnId}',
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppText(
                  statusMeta.$2,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusMeta.$1,
                  ),
                ),
              ],
            ),
            if ((txn.message).isNotEmpty) ...[
              AppSpacing.h10,
              Divider(height: 1, color: context.cs.outlineVariant),
              AppSpacing.h8,
              AppText(
                txn.message,
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
            AppSpacing.h8,
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                AppText(
                  AppDateFormatter.formatDateTime(txn.createdAt),
                  style: context.tt.labelSmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppText(
                  '$currencySymbol${txn.amount}',
                  style: context.tt.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, String) _paymentMeta(BuildContext context, String type) {
    for (final gateway in PaymentGatewayType.values) {
      if (gateway.apiValue.toLowerCase() == type.toLowerCase()) {
        return (context.translate(gateway.label), gateway.iconPath);
      }
    }
    return (type, AssetsConstants.walletIcon);
  }

  (Color, String) _statusMeta(BuildContext context, String status) {
    final s = status.trim().toLowerCase();
    final label = s == '1' || s == '0' || s == '2'
        ? status
        : status.trim().isEmpty
        ? status
        : '${status.trim()[0].toUpperCase()}${status.trim().substring(1)}';
    return switch (TransactionStatus.fromRaw(status)) {
      TransactionStatus.success => (
        context.cs.tertiaryFixed,
        s == '1' ? context.translate(LanguageLabelKeys.success) : label,
      ),
      TransactionStatus.failed => (
        context.cs.onSecondaryFixed,
        s == '2' ? context.translate(LanguageLabelKeys.failed) : label,
      ),
      TransactionStatus.pending => (
        context.cs.onTertiaryFixed,
        s == '0' ? context.translate(LanguageLabelKeys.filterPending) : label,
      ),
      TransactionStatus.unknown => (context.cs.onSurfaceVariant, status),
    };
  }
}
