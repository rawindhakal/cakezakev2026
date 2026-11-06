import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/cash_collection_model.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Card displaying a single cash collection transaction entry.
class CashCollectionCard extends StatelessWidget {
  final CashCollectionModel item;

  const CashCollectionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final currencySymbol = item.currency ?? "";

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
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
      child: ClipRRect(
        borderRadius: AppRadius.r14,
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          AppText(
                            '${context.translate(LanguageLabelKeys.orderId)}${AppConstants.hashSymbol}${item.orderId ?? item.id ?? '—'}',
                            style: context.tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurface,
                            ),
                          ),
                          AppText(
                            AppDateFormatter.formatDateTime(
                              item.transactionDate ?? item.createdAt,
                            ),
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppText(
                      (item.status ?? '—').capitalize,
                      style: context.tt.labelMedium?.copyWith(
                        color: context.cs.primary,
                      ),
                    ),
                  ],
                ),
                AppSpacing.h10,
                Divider(height: 1, color: context.cs.outlineVariant),
                AppSpacing.h10,
                AppText(
                  context.translate(LanguageLabelKeys.message),
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                AppText(
                  (item.message ?? '').isNotEmpty ? item.message! : '—',
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: .ellipsis,
                ),
                AppSpacing.h10,
                Divider(height: 1, color: context.cs.outlineVariant),
                AppSpacing.h10,
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        context.translate(LanguageLabelKeys.amount),
                        style: context.tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.cs.onSurface,
                        ),
                      ),
                    ),
                    AppText(
                      '$currencySymbol${item.amount ?? '0'}',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
