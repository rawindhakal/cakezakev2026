import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// [WithdrawRequests.fromJson] calls `.toString()` on possibly-null API
/// fields, turning an absent value into the literal string "null" instead
/// of a real null — normalize that back to blank here.
String? _clean(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
    return null;
  }
  return trimmed;
}

/// Opens a bottom sheet showing a wallet transaction's message/remark, if
/// either is present. Callers should check [hasWalletTransactionDetail]
/// before wiring the tap so rows with nothing to show stay unclickable.
bool hasWalletTransactionDetail({String? message, String? remark}) {
  return _clean(message) != null || _clean(remark) != null;
}

void showWalletTransactionDetailSheet(
  BuildContext context, {
  String? message,
  String? remark,
}) {
  final cleanMessage = _clean(message);
  final cleanRemark = _clean(remark);

  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.transactionDetail),
    builder: (sheetContext) => SlideAnimationList(
      crossAxisAlignment: .start,
      children: [
        if (cleanMessage != null) ...[
          AppText(
            sheetContext.translate(LanguageLabelKeys.message),
            style: sheetContext.tt.labelMedium?.copyWith(
              color: sheetContext.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h4,
          AppText(
            cleanMessage,
            style: sheetContext.tt.bodyMedium?.copyWith(
              color: sheetContext.cs.onSurface,
            ),
          ),
        ],
        if (cleanMessage != null && cleanRemark != null) AppSpacing.h16,
        if (cleanRemark != null) ...[
          AppText(
            sheetContext.translate(LanguageLabelKeys.remarks),
            style: sheetContext.tt.labelMedium?.copyWith(
              color: sheetContext.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h4,
          AppText(
            cleanRemark,
            style: sheetContext.tt.bodyMedium?.copyWith(
              color: sheetContext.cs.onSurface,
            ),
          ),
        ],
      ],
    ),
  );
}
