import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Compact stat tile (icon, value, label) used in the quick-access/wallet earnings sections.
class EarningsStatCard extends StatelessWidget {
  final String icon;
  final Color accentColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const EarningsStatCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: context.cs.surface,
        borderRadius: AppRadius.r16,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.r16,
          child: Container(
            padding: const EdgeInsetsDirectional.all(14),
            decoration: AppDecorations.card(borderRadius: AppRadius.r16),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AppSvgIcon(icon, color: accentColor, size: ThemeConstants.iconL),
                AppSpacing.h10,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: AppText(
                    value,
                    maxLines: 1,
                    style: context.tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
                AppSpacing.h4,
                AppText(
                  label,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: context.tt.labelSmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
