import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Shared date-icon + clear-filter row used by the Quick Order, Ecommerce and
/// Return Request filter bars. Purely presentational — callers compute
/// [hasDate]/[hasActiveFilters] from their own cubit and pass primitives down.
class OrderDateFilterRow extends StatelessWidget {
  final bool hasDate;
  final bool hasActiveFilters;
  final String dateTooltip;
  final VoidCallback onPickDate;
  final VoidCallback onClear;

  const OrderDateFilterRow({
    super.key,
    required this.hasDate,
    required this.hasActiveFilters,
    required this.dateTooltip,
    required this.onPickDate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        Stack(
          clipBehavior: .none,
          children: [
            IconButton(
              icon: AppSvgIcon(
                AssetsConstants.dateIcon,
                color: hasDate ? context.cs.primary : context.cs.onSurfaceVariant,
              ),
              onPressed: onPickDate,
              tooltip: dateTooltip,
            ),
            if (hasDate)
              PositionedDirectional(
                end: 10,
                top: 10,
                child: SizedBox(
                  width: context.screenWidth * 0.019,
                  height: context.screenWidth * 0.019,
                  child: DecoratedBox(
                    decoration: AppDecorations.circle(color: context.cs.primary),
                  ),
                ),
              ),
          ],
        ),
        if (hasActiveFilters) ...[
          AppSpacing.w4,
          Tooltip(
            message: context.translate(LanguageLabelKeys.clear),
            child: InkWell(
              onTap: onClear,
              borderRadius: AppRadius.r10,
              child: Container(
                width: context.screenWidth * 0.107,
                height: context.screenWidth * 0.107,
                alignment: Alignment.center,
                decoration: AppDecorations.outlinedCard(
                  color: context.cs.surface,
                  borderColor: context.cs.outline,
                ),
                child: AppSvgIcon(
                  AssetsConstants.closeIcon,
                  size: ThemeConstants.iconM,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        AppSpacing.w4,
      ],
    );
  }
}
