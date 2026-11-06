import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Opens a bottom sheet with a salary payment's note, mirroring the wallet
/// transaction detail sheet. Callers should check [hasSalaryDetail] first.
bool hasSalaryDetail(String? note) {
  final trimmed = note?.trim();
  return trimmed != null &&
      trimmed.isNotEmpty &&
      trimmed.toLowerCase() != 'null';
}

void showSalaryDetailSheet(BuildContext context, String? note) {
  final message = note!.trim();

  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.transactionDetail),
    builder: (sheetContext) => SlideAnimationList(
      crossAxisAlignment: .start,
      children: [
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
    ),
  );
}
