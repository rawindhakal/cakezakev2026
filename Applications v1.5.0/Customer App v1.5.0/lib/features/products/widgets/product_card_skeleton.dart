import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Common grid of [ProductCardSkeleton] items, sized off the actual cell
/// width same way [ProductCard] grids are — reused by every screen that
/// shows a product grid loading state instead of each re-deriving the
/// crossAxisCount/mainAxisExtent math locally.
class ProductGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final EdgeInsetsGeometry padding;
  final double edgePad;
  final double spacing;
  final double mainAxisSpacing;

  const ProductGridSkeleton({
    super.key,
    required this.crossAxisCount,
    this.padding = const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
    this.edgePad = 16.0,
    this.spacing = 8.0,
    this.mainAxisSpacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - edgePad - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final isCompact = cardWidth < 140;
        final imageHeight = (cardWidth * 1.3).clamp(140.0, 280.0);
        final belowHeight = isCompact ? 148.0 : 160.0;
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: mainAxisSpacing,
            mainAxisExtent: imageHeight + belowHeight,
          ),
          itemCount: crossAxisCount * 3,
          itemBuilder: (context, i) => const ProductCardSkeleton(),
        );
      },
    );
  }
}

/// Mirrors [ProductCard]'s shape (image, price, name, rating) so product
/// grids don't jump layout once real cards swap in. Shares the same
/// pulsing color-lerp animation as the other skeleton loaders in the app.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final isCompact = cardWidth < 140;
        final imageHeight = (cardWidth * 1.3).clamp(140.0, 280.0);

        return ShimmerBuilder(
          builder: (context, color) => Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              ShimmerBox(
                color,
                width: double.infinity,
                height: imageHeight,
                radius: AppRadius.r8,
              ),
              SizedBox(height: isCompact ? 6 : 8),
              ShimmerBox(
                color,
                width: cardWidth * 0.45,
                height: isCompact ? 14 : 17,
              ),
              AppSpacing.h6,
              ShimmerBox(
                color,
                width: double.infinity,
                height: isCompact ? 11 : 13,
              ),
              AppSpacing.h4,
              ShimmerBox(
                color,
                width: cardWidth * 0.6,
                height: isCompact ? 11 : 13,
              ),
              AppSpacing.h6,
              ShimmerBox(
                color,
                width: cardWidth * 0.35,
                height: isCompact ? 11 : 13,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mirrors [ProductListItem]'s row shape (details left, 130x130 image
/// right) so the list layout's loading state doesn't flash a portrait
/// grid card in a horizontal row.
class ProductListItemSkeleton extends StatelessWidget {
  const ProductListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingS,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.box(
          color: context.cs.surface,
          border: Border.all(color: context.cs.outlineVariant),
          borderRadius: AppRadius.r8,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    ShimmerBox(color, width: double.infinity, height: 14),
                    AppSpacing.h6,
                    ShimmerBox(color, width: 120, height: 14),
                    AppSpacing.h10,
                    ShimmerBox(color, width: 90, height: 20),
                    AppSpacing.h8,
                    ShimmerBox(color, width: 70, height: 12),
                  ],
                ),
              ),
              AppSpacing.w12,
              ShimmerBox(color, width: 130, height: 130, radius: AppRadius.r8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Common list of [ProductListItemSkeleton] rows — the list-mode
/// counterpart to [ProductGridSkeleton], used by every screen's list-layout
/// loading state.
class ProductListSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final int itemCount;

  const ProductListSkeleton({
    super.key,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: ThemeConstants.paddingL,
      vertical: ThemeConstants.paddingL,
    ),
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => AppSpacing.h10,
      itemBuilder: (context, i) => const ProductListItemSkeleton(),
    );
  }
}
