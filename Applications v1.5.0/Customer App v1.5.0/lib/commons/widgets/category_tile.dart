import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/extensions/context_extensions.dart';

enum CategoryTileShape { roundedSquare, circle }

// Shared tile for category grid (CategoryScreen / SubCategoryChildrenPanel)
// and home category blocks (CategoryBlock). imageSize == null -> Expanded
// flex mode that fills the parent grid cell (tablet-aware 5:3 / 6:2 split).
// imageSize != null -> fixed pixel mode used where the caller pre-scales
// sizes itself (home horizontal list / circular grid).
class CategoryTile extends StatelessWidget {
  final String imageUrl;
  final String name;
  final VoidCallback? onTap;
  final CategoryTileShape shape;
  final double? imageSize;
  final double borderRadius;
  final double? labelFontSize;
  final double? labelWidth;
  final Color? textColor;

  const CategoryTile({
    super.key,
    required this.imageUrl,
    required this.name,
    this.onTap,
    this.shape = CategoryTileShape.roundedSquare,
    this.imageSize,
    this.borderRadius = 12,
    this.labelFontSize,
    this.labelWidth,
    this.textColor,
  });

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor ?? context.cs.onSurface;

    if (imageSize == null) {
      final isTablet = _isTablet(context);
      final fontSize = labelFontSize ?? (isTablet ? 13.0 : 10.0);
      return GestureDetector(
        onTap: onTap,
        child: Column(
          spacing: ThemeConstants.spaceXS,
          children: [
            Expanded(
              flex: isTablet ? 5 : 6,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: AppDecorations.box(
                  color: context.cs.secondaryFixed,
                  borderRadius: AppRadius.r12,
                ),
                child: AppNetworkImage(
                  url: imageUrl,
                  borderRadius: AppRadius.r10,
                ),
              ),
            ),
            Expanded(
              flex: isTablet ? 3 : 2,
              child: Center(
                child: AppText(
                  name,
                  style: context.tt.titleSmall?.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: resolvedTextColor,
                    height: 1.3,
                  ),
                  textAlign: .center,
                  maxLines: 2,
                  overflow: .ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final size = imageSize!;
    final image = AppNetworkImage(url: imageUrl, fit: BoxFit.contain);
    final imageWidget = shape == CategoryTileShape.circle
        ? CircleAvatar(
            radius: size / 2,
            backgroundColor: context.cs.outline.withValues(alpha: 0.3),
            child: ClipOval(child: image),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              width: size,
              height: size,
              color: context.cs.secondaryFixed,
              child: image,
            ),
          );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: .min,
        mainAxisAlignment: .start,
        crossAxisAlignment: .center,
        spacing: ThemeConstants.spaceXS,
        children: [
          imageWidget,
          SizedBox(
            width: labelWidth ?? 64,
            child: AppText(
              name,
              style: context.tt.labelLarge?.copyWith(
                fontSize: labelFontSize ?? 10,
                fontWeight: FontWeight.w600,
                color: resolvedTextColor,
              ),
              textAlign: .center,
              maxLines: 2,
              overflow: .ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryTileShimmer extends StatelessWidget {
  const CategoryTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => Column(
        spacing: ThemeConstants.spaceXS,
        children: [
          Expanded(
            flex: 6,
            child: ShimmerBox(
              color,
              width: double.infinity,
              height: double.infinity,
              radius: AppRadius.r10,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(child: ShimmerBox(color, width: 40, height: 10)),
          ),
        ],
      ),
    );
  }
}
