import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../commons/widgets/app_svg_icon.dart';
import '../../../core/theme/app_radius.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/size_extensions.dart';
import '../../../commons/widgets/app_text.dart';

/// Flat gray-tile stat card (icon + title row, subtitle below) used on the home dashboard.
class DashboardStatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
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
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Row(
              spacing: ThemeConstants.spaceM,
              children: [
                Container(
                  width: context.screenWidth * 0.085,
                  height: context.screenWidth * 0.085,
                  padding: EdgeInsetsDirectional.all(5),
                  decoration: AppDecorations.circle(
                    color: context.cs.surfaceContainerHighest,
                  ),
                  child: AppSvgIcon(
                    icon,
                    color: context.cs.onSurface,
                    size: ThemeConstants.iconXS,
                    fit: BoxFit.scaleDown,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    // Sizes to its content: with the default (max) this column
                    // demands the row's full height and overflows by a pixel
                    // once the real font's metrics are slightly taller than
                    // the fallback's.
                    mainAxisSize: MainAxisSize.min,
                    spacing: ThemeConstants.spaceXXS,
                    children: [
                      // Both lines are Flexible so they give way instead of
                      // overflowing: the row leaves this column only as much
                      // height as the icon needs, which the label + value are
                      // within a pixel of once the real font's metrics differ
                      // slightly from the fallback's.
                      Flexible(
                        child: AppText(
                          label,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: context.tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: AppText(
                            value,
                            maxLines: 1,
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
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
