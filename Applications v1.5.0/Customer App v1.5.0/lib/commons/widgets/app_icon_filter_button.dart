import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Bordered 44x44 icon card — highlights [isActive] with the primary color.
/// Shared by [AppSearchFilterBar] and the orders screen's date-filter actions.
class AppIconFilterButton extends StatelessWidget {
  final String icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const AppIconFilterButton({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.r10,
        child: Container(
          width: 44,
          height: 44,
          decoration: AppDecorations.outlinedCard(
            color: isActive ? context.cs.primaryContainer : context.cs.surface,
            borderColor: isActive ? context.cs.primary : context.cs.outline,
          ),
          child: AppSvgIcon(
            icon,
            size: ThemeConstants.iconS,
            color: isActive ? context.cs.primary : context.cs.onSurfaceVariant,
            fit: BoxFit.scaleDown,
          ),
        ),
      ),
    );
  }
}

/// Single bordered card holding a primary action icon and an optional
/// secondary icon (e.g. clear) — used where two related actions (like "pick
/// date" + "clear date") should read as one control instead of two separate
/// cards. Both icons shrink slightly when the secondary one is shown, so the
/// combined card doesn't grow past the usual 44x44 footprint.
class AppIconFilterButtonGroup extends StatelessWidget {
  final String icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;
  final String? secondaryIcon;
  final VoidCallback? onSecondaryTap;
  final String? secondaryTooltip;

  const AppIconFilterButtonGroup({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
    this.secondaryIcon,
    this.onSecondaryTap,
    this.secondaryTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final showSecondary = secondaryIcon != null && onSecondaryTap != null;
    final cellWidth = showSecondary ? 22.0 : 44.0;
    final iconSize = showSecondary ? 9.0 : 18.0;

    // No card/border when there's nothing to combine with — just the plain
    // icon button, matching the rest of the app bar actions.
    if (!showSecondary) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: cellWidth,
            height: 38,
            child: AppSvgIcon(
              icon,
              size: iconSize,
              color: context.cs.onSurfaceVariant,
              fit: BoxFit.scaleDown,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 38,
      decoration: AppDecorations.outlinedCard(
        color: isActive ? context.cs.primaryContainer : context.cs.surface,
        borderColor: isActive ? context.cs.primary : context.cs.outline,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            Tooltip(
              message: tooltip,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: cellWidth,
                  height: 38,
                  child: AppSvgIcon(
                    icon,
                    size: iconSize,
                    color: isActive
                        ? context.cs.primary
                        : context.cs.onSurfaceVariant,
                    fit: BoxFit.scaleDown,
                  ),
                ),
              ),
            ),
            if (showSecondary)
              Tooltip(
                message: secondaryTooltip ?? '',
                child: InkWell(
                  onTap: onSecondaryTap,
                  child: SizedBox(
                    width: cellWidth,
                    height: 38,
                    child: AppSvgIcon(
                      secondaryIcon!,
                      size: iconSize,
                      color: isActive
                          ? context.cs.primary
                          : context.cs.onSurfaceVariant,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
