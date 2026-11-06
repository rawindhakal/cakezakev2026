import 'package:flutter/material.dart';

/// Builds the widget for cell [index] within a row whose cells are all
/// [cardWidth] wide — pass this straight into ProductCard's `cardWidth` so it
/// skips its internal LayoutBuilder.
typedef ProductCardGridItemBuilder =
    Widget Function(BuildContext context, int index, double cardWidth);

/// Row-based replacement for GridView with SliverGridDelegateWithFixedCrossAxisCount.
///
/// A fixed mainAxisExtent forces every row in the whole grid to the same
/// height (tuned for the worst-case card content), so rows whose cards have
/// less content are left with dead space at the bottom. Here each row is a
/// plain Row of Expanded cells: Flex already sizes itself to its tallest
/// child with no stretch needed (ProductCard's Column is mainAxisSize.min,
/// so it never fills extra height anyway), so a row of short cards shrinks
/// and a row with one long card doesn't affect any other row.
///
/// Deliberately NOT using IntrinsicHeight here — it forces a two-pass
/// intrinsic layout on its child, and ProductCard contains a Hero; that
/// combination trips a framework assertion during Hero flight
/// ('!semantics.parentDataDirty') because RenderIntrinsicHeight doesn't
/// correctly hand off semantics parent data while its child is reparented
/// into the Hero overlay mid-animation.
class ProductCardGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final ProductCardGridItemBuilder itemBuilder;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const ProductCardGrid({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final rowCount = (itemCount / crossAxisCount).ceil();
    final resolvedPadding =
        padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth - resolvedPadding.horizontal;
        final cardWidth =
            (availableWidth - crossAxisSpacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return ListView.builder(
          controller: controller,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          // ignore: deprecated_member_use
          cacheExtent: 600,
          addAutomaticKeepAlives: false,
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            final start = rowIndex * crossAxisCount;
            return RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: rowIndex == rowCount - 1 ? 0 : mainAxisSpacing,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < crossAxisCount; col++) ...[
                      if (col > 0) SizedBox(width: crossAxisSpacing),
                      Expanded(
                        child: start + col < itemCount
                            ? itemBuilder(context, start + col, cardWidth)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
