import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// Outlined date-range picker card shared by every filter sheet so the
/// date-range control looks identical across the app.
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
                  padding: const EdgeInsets.all(ThemeConstants.paddingXS),
                  child: AppSvgIcon(
                    AssetsConstants.closeIcon,
                    size: ThemeConstants.iconXS,
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
