import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// Outlined date-range picker card shared by every filter sheet (orders,
/// settlement history, ...) so the date-range control looks identical
/// across the app.
class DateRangeFilterField extends StatelessWidget {
  final String? startDate;
  final String? endDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const DateRangeFilterField({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = startDate != null && endDate != null;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.r10,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.outlinedCard(
          color: context.cs.surface,
          borderColor: hasDate ? context.cs.primary : context.cs.outline,
        ),
        child: Row(
          children: [
            AppSvgIcon(
              AssetsConstants.dateIcon,
              size: ThemeConstants.iconS,
              color: hasDate ? context.cs.primary : context.cs.onSurfaceVariant,
            ),
            AppSpacing.w8,
            Expanded(
              child: AppText(
                hasDate
                    ? '$startDate → $endDate'
                    : context.translate(LanguageLabelKeys.startDateEndDate),
              ),
            ),
            if (hasDate)
              InkWell(
                onTap: onClear,
                borderRadius: AppRadius.r10,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AppSvgIcon(
                    AssetsConstants.closeIcon,
                    size: ThemeConstants.iconM,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
