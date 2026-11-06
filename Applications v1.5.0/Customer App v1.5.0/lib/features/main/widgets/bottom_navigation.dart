import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/features/main/models/bottom_navigation.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

import '../../../utils/extensions/context_extensions.dart';
import 'package:customer/core/theme/app_decorations.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.bottomSheetFooter(
        color: context.cs.surface,
        borderColor: context.cs.outlineVariant.withValues(alpha: 0.3),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: ThemeConstants.bottomBarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: List.generate(widget.items.length, (i) {
                  final isActive = i == widget.currentIndex;
                  final item = widget.items[i];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isActive) AppHaptics.tick();
                        widget.onTap(i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: .center,
                        spacing: ThemeConstants.spaceXXS,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: _buildNavIcon(item, isActive, context, i),
                          ),
                          AppText(
                            item.label,
                            style: context.tt.labelSmall?.copyWith(
                              color: isActive
                                  ? context.cs.onSurface
                                  : context.cs.onSurfaceVariant,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            textAlign: .center,
                            maxLines: 1,
                            overflow: .ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              PositionedDirectional(
                start:
                    (context.screenWidth / widget.items.length) *
                        widget.currentIndex +
                    ((context.screenWidth / widget.items.length) * 0.2),
                // Overlap the container's 1px top border so no gap shows
                // between the indicator and the bar edge.
                top: -1,
                width: (context.screenWidth / widget.items.length) * 0.6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3,
                  decoration: AppDecorations.box(
                    color: context.cs.onSurface,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(5),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(
    BottomNavItem item,
    bool isActive,
    BuildContext context,
    int index,
  ) {
    final String? path = isActive ? item.activeIconPath : item.inactiveIconPath;
    if (path != null && path.isNotEmpty) {
      final cs = context.cs;
      // Bottom nav "Primary"/"Primary Shade" opacity roles: not colors, so
      // they can't live on ColorScheme — kept as brightness-conditional
      // constants here instead (light: 1.0/0.2, dark: 0.18/0.5). category/
      // profile active icons lean on small solid-fill shapes with no
      // supporting stroke, so the 0.18 dark dim washes them out to
      // near-invisible — keep those two at full opacity; other icons (whose
      // solid fill is a supporting shape, not the whole silhouette) keep the
      // original dim so the dark-mode look stays consistent for them.
      final isSmallSolidIcon =
          path.contains('category_active') || path.contains('profile_active');
      final primaryOpacity = context.isDark && !isSmallSolidIcon ? 0.18 : 1.0;
      final primaryShadeOpacity = context.isDark ? 0.5 : 0.2;
      return AppSvgIcon(
        path,
        key: ValueKey(path + (isActive ? '-active' : '-inactive')),
        size: ThemeConstants.iconL,
        colorMapper: AppSvgColorMapper(
          cs.primary,
          cs.onSecondaryFixedVariant,
          bottomNavBlackColor: isActive ? cs.primaryFixed : cs.onSecondary,
          bottomNavLightGrayColor: isActive ? null : cs.tertiaryFixedDim,
          bottomNavConstantColor: isActive ? cs.primaryFixedDim : null,
          bottomNavPrimaryOpacity: isActive ? primaryOpacity : null,
          bottomNavPrimaryShadeOpacity: primaryShadeOpacity,
        ),
      );
    }
    return SizedBox.shrink();
  }
}
