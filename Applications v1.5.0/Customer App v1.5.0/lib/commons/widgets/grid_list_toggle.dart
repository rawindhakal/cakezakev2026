import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Generic grid/list layout switch — used by any product-listing screen
/// (favourites, brand products, category products, ...).
class GridListToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onToggle;
  final double? height;

  const GridListToggle({
    super.key,
    required this.isGrid,
    required this.onToggle,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bg = context.cs.surfaceContainerHigh;
    final inactiveColor = context.cs.onSurfaceVariant;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 0 && !isGrid) {
          onToggle(true);
        } else if (velocity < 0 && isGrid) {
          onToggle(false);
        }
      },
      child: Container(
        height: height ?? context.heightFraction(0.045),
        decoration: AppDecorations.box(color: bg, borderRadius: AppRadius.pill),
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
        child: IntrinsicWidth(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: isGrid
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: Container(
                    decoration: AppDecorations.box(
                      color: context.cs.surface,
                      borderRadius: AppRadius.pill,
                      boxShadow: [
                        BoxShadow(
                          color: context.cs.shadow.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: .min,
                children: [
                  _ToggleBtn(
                    icon: AssetsConstants.listIcon,
                    active: !isGrid,
                    inactiveColor: inactiveColor,
                    onTap: () => onToggle(false),
                  ),
                  _ToggleBtn(
                    icon: AssetsConstants.gridIcon,
                    active: isGrid,
                    inactiveColor: inactiveColor,
                    onTap: () => onToggle(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String icon;
  final bool active;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingS,
          vertical: ThemeConstants.paddingXS / 2,
        ),
        child: AppSvgIcon(
          icon,
          size: ThemeConstants.iconXS,
          color: active ? context.cs.onSurface : inactiveColor,
          bakeTint: true,
        ),
      ),
    );
  }
}
