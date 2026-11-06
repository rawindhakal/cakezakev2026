import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Icon + bold title row followed by a divider — shared header for
/// note-style detail-card sections (order note, return reason) so both
/// read as one consistent pattern instead of duplicating the same row.
class SectionIconHeader extends StatelessWidget {
  final String icon;
  final String title;
  const SectionIconHeader({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            AppSvgIcon(
              icon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurface,
            ),
            AppSpacing.w6,
            Expanded(
              child: AppText(
                title,
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 10),
          child: Divider(height: 1, color: context.cs.outlineVariant),
        ),
      ],
    );
  }
}
