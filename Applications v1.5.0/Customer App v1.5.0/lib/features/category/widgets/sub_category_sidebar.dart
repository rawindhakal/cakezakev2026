import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Sidebar geometry, measured off Blinkit's category rail (77dp wide, 4dp
/// selection bar on the trailing edge, 56dp avatar circle).
abstract final class SidebarMetrics {
  static const double width = 77;
  static const double indicatorWidth = 4;
  static const double circle = 56;
  static const double image = 50;
  static const EdgeInsetsDirectional itemPadding = EdgeInsetsDirectional.only(
    top: 13,
    bottom: 4,
    start: 2,
    end: indicatorWidth + 2,
  );

  // Selected: image grows and lifts so it pokes out of the top of the circle.
  static const double selectedScale = 1.12;
  static const double selectedLift = 10.5;
  static const Duration imageDuration = Duration(milliseconds: 300);
}

class SidebarLoader extends StatelessWidget {
  final Color bg;
  const SidebarLoader({super.key, required this.bg});

  @override
  Widget build(BuildContext context) {
    final shimmer = context.cs.surfaceContainerHigh;
    return Container(
      color: bg,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, _) => Padding(
          padding: SidebarMetrics.itemPadding,
          child: Column(
            spacing: ThemeConstants.spaceS,
            children: [
              Container(
                width: SidebarMetrics.circle,
                height: SidebarMetrics.circle,
                decoration: AppDecorations.box(color: shimmer, shape: .circle),
              ),
              Container(
                width: 44,
                height: 8,
                decoration: AppDecorations.box(
                  color: shimmer,
                  borderRadius: AppRadius.r4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = category.name?.isNotEmpty == true ? category.name! : '';
    // Grow/lift eases out on select; settling back eases in, like Blinkit.
    final curve = isSelected ? Curves.linearToEaseOut : Curves.easeInToLinear;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: SidebarMetrics.itemPadding,
        child: Column(
          spacing: ThemeConstants.spaceXS,
          children: [
            SizedBox.square(
              dimension: SidebarMetrics.circle,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: AppDecorations.box(
                        shape: .circle,
                        color: isSelected
                            ? context.cs.primary.withValues(alpha: 0.08)
                            : context.cs.surfaceContainer,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipPath(
                      clipper: const _CircleBottomClipper(),
                      child: Center(
                        child: AnimatedSlide(
                          duration: SidebarMetrics.imageDuration,
                          curve: curve,
                          offset: isSelected
                              ? const Offset(
                                  0,
                                  -SidebarMetrics.selectedLift /
                                      SidebarMetrics.image,
                                )
                              : Offset.zero,
                          child: AnimatedScale(
                            duration: SidebarMetrics.imageDuration,
                            curve: curve,
                            scale: isSelected
                                ? SidebarMetrics.selectedScale
                                : 1.0,
                            // Fixed size (not LayoutBuilder-derived) so the
                            // decode cache key never shifts with selection.
                            child: AppNetworkImage(
                              url: category.imageUrl ?? '',
                              width: SidebarMetrics.image,
                              height: SidebarMetrics.image,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppText(
              name,
              style: context.tt.labelSmall?.copyWith(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? context.cs.onSurface
                    : context.cs.onSurfaceVariant,
                height: 1.2,
              ),
              textAlign: .center,
              maxLines: 2,
              overflow: .ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Clips to the circle's lower half only — the selected image is free to
/// spill out over the top and sides, but stays tucked inside the bowl.
class _CircleBottomClipper extends CustomClipper<Path> {
  const _CircleBottomClipper();

  @override
  Path getClip(Size size) {
    final r = size.width / 2;
    return Path()
      ..addOval(Offset.zero & size)
      ..addRect(Rect.fromLTRB(-r, -size.height, size.width + r, r));
  }

  @override
  bool shouldReclip(covariant _CircleBottomClipper oldClipper) => false;
}

/// Trailing selection bar. Its rect is driven by [SubCategorySidebarPanel]
/// so it can glide between items instead of popping in per item.
class SidebarIndicator extends StatelessWidget {
  const SidebarIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.box(
        color: context.cs.primary,
        borderRadius: AppRadius.left30,
      ),
    );
  }
}
