import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import '../models/settlement_history_model.dart';

/// Opens a bottom sheet with a settlement entry's opening/closing balance
/// and message, mirroring the wallet transaction detail sheet.
void showSettlementHistoryDetailSheet(
  BuildContext context,
  SettlementHistoryData item, {
  required String currencySymbol,
}) {
  final message = item.message?.trim();
  final hasMessage =
      message != null && message.isNotEmpty && message.toLowerCase() != 'null';

  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.transactionDetail),
    builder: (sheetContext) => SlideAnimationList(
      crossAxisAlignment: .start,
      children: [
        if (item.entryType?.trim().isNotEmpty ?? false) ...[
          AppText(
            sheetContext.translate(LanguageLabelKeys.settlementType),
            style: sheetContext.tt.labelMedium?.copyWith(
              color: sheetContext.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h4,
          AppText(
            item.entryType!.trim(),
            style: sheetContext.tt.bodyMedium?.copyWith(
              color: sheetContext.cs.onSurface,
            ),
          ),
          AppSpacing.h16,
        ],
        AppText(
          sheetContext.translate(LanguageLabelKeys.openingBalance),
          style: sheetContext.tt.labelMedium?.copyWith(
            color: sheetContext.cs.onSurfaceVariant,
          ),
        ),
        AppSpacing.h4,
        AppText(
          '$currencySymbol${item.openingBalance ?? 0}',
          style: sheetContext.tt.bodyMedium?.copyWith(
            color: sheetContext.cs.onSurface,
          ),
        ),
        AppSpacing.h16,
        AppText(
          sheetContext.translate(LanguageLabelKeys.closingBalance),
          style: sheetContext.tt.labelMedium?.copyWith(
            color: sheetContext.cs.onSurfaceVariant,
          ),
        ),
        AppSpacing.h4,
        AppText(
          '$currencySymbol${item.closingBalance ?? 0}',
          style: sheetContext.tt.bodyMedium?.copyWith(
            color: sheetContext.cs.onSurface,
          ),
        ),
        if (hasMessage) ...[
          AppSpacing.h16,
          AppText(
            sheetContext.translate(LanguageLabelKeys.message),
            style: sheetContext.tt.labelMedium?.copyWith(
              color: sheetContext.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h4,
          AppText(
            message,
            style: sheetContext.tt.bodyMedium?.copyWith(
              color: sheetContext.cs.onSurface,
            ),
          ),
        ],
      ],
    ),
  );
}
