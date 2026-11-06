import 'package:flutter/material.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/theme/app_decorations.dart';

class ProductCardPaginationDots extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final double dotSize;
  final double dotHeight;
  final bool isDark;

  const ProductCardPaginationDots({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.dotSize,
    required this.dotHeight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisible = 4;
    final visibleCount = pageCount < maxVisible ? pageCount : maxVisible;
    final pitch =
        dotHeight + 1; // dot diameter + horizontal margin (0.5 each side)
    final maxStart = pageCount - visibleCount;
    final windowStart = (currentPage - 1).clamp(0, maxStart < 0 ? 0 : maxStart);
    final inactiveColor = context.cs.onSurfaceVariant;
    final activeBgColor = context.cs.surface;
    final activeBorderColor = context.cs.onSurfaceVariant;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final slideSign = isRTL ? 1.0 : -1.0;

    return ClipRect(
      child: SizedBox(
        width: pitch * visibleCount,
        height: dotHeight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            slideSign * windowStart * pitch,
            0,
            0,
          ),
          child: OverflowBox(
            minWidth: 0,
            maxWidth: pitch * pageCount,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: List.generate(pageCount, (i) {
                final active = i == currentPage;
                final distance = (i - currentPage).abs();
                final size = active
                    ? dotHeight * 1.8
                    : (dotSize - distance * 1.0).clamp(3.0, dotSize);
                return Container(
                  width: dotHeight,
                  height: dotHeight,
                  margin: const EdgeInsetsDirectional.symmetric(
                    horizontal: 0.5,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: size,
                    height: size,
                    decoration: AppDecorations.box(
                      color: active ? activeBgColor : inactiveColor,
                      shape: .circle,
                      border: active
                          ? Border.all(color: activeBorderColor, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
