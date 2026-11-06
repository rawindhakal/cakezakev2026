import 'package:deliveryboy/commons/utils/app_haptics.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/features/main/models/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

import '../../../utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';

/// Custom bottom navigation bar with animated icon switching and active indicator.
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

/// State for [BottomNavBar] (public to allow external access via a [GlobalKey]).
class BottomNavBarState extends State<BottomNavBar> {
  @override
  void dispose() {
    super.dispose();
  }

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
          height: context.screenHeight * 0.074,
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
                      behavior: .opaque,
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
                            overflow: TextOverflow.ellipsis,
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
                  height: context.screenHeight * 0.004,
                  decoration: AppDecorations.card(
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
      final isDark = context.isDark;
      // profile_active.svg's solid-fill role is a small circle with no
      // supporting large-area shape, so the 0.18 dark-mode dim washes it out
      // to near-invisible — keep it at full opacity. Other icons (order,
      // home, wallet) use large solid regions that stay readable dimmed, so
      // they keep the original dim for a consistent dark-mode look.
      final isSmallSolidIcon = path.contains('profile_active');
      return AppSvgIcon(
        path,
        key: ValueKey(path + (isActive ? '-active' : '-inactive')),
        size: context.screenWidth * 0.064,
        colorMapper: AppSvgColorMapper(
          context.cs.primary,
          context.cs.outline,
          bottomNavBlackColor: isActive
              ? context.cs.tertiaryFixed
              : context.cs.onSecondary,
          bottomNavLightGrayColor: isActive ? null : context.cs.surfaceDim,
          bottomNavConstantColor: isActive ? context.cs.surfaceBright : null,
          // ColorScheme has no numeric role, so these two opacities stay
          // literal — the colors themselves already resolve via cs above.
          bottomNavPrimaryOpacity: isActive
              ? (isDark && !isSmallSolidIcon ? 0.18 : 1.0)
              : null,
          bottomNavPrimaryShadeOpacity: isDark ? 0.5 : 0.2,
        ),
      );
    }

    return SizedBox.shrink();
  }
}
