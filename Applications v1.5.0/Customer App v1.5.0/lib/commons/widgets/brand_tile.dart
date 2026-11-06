import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/extensions/context_extensions.dart';

enum BrandTileShape { roundedSquare, circle }

// Shared tile for BrandBlock's horizontal/grid (roundedSquare) and
// circular layouts. `size` means box width/height for roundedSquare, and
// CircleAvatar radius for circle — same meaning as the caller's existing
// tileSize / circleRadius values, so no conversion needed at call sites.
class BrandTile extends StatelessWidget {
  final String imageUrl;
  final String name;
  final VoidCallback? onTap;
  final BrandTileShape shape;
  final double size;
  final double borderRadius;
  final double labelFontSize;
  final double labelWidth;
  final Color? textColor;
  final bool? showName;

  const BrandTile({
    super.key,
    required this.imageUrl,
    required this.name,
    this.onTap,
    this.shape = BrandTileShape.roundedSquare,
    this.size = 60,
    this.borderRadius = 12,
    this.labelFontSize = 11,
    this.labelWidth = 64,
    this.textColor,
    this.showName,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor ?? context.cs.onSurface;
    final image = AppNetworkImage(url: imageUrl, fit: BoxFit.contain);

    final imageWidget = shape == BrandTileShape.circle
        ? CircleAvatar(
            radius: size,
            backgroundColor: context.cs.outline.withValues(alpha: 0.3),
            child: ClipOval(child: image),
          )
        : Container(
            width: size,
            height: size,
            decoration: AppDecorations.box(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: context.cs.outline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: image,
            ),
          );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceS,
        children: [
          imageWidget,
          (showName ?? true)
              ? SizedBox(
                  width: labelWidth,
                  child: AppText(
                    name,
                    style: context.tt.labelMedium?.copyWith(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w500,
                      color: resolvedTextColor,
                    ),
                    textAlign: .center,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                )
              : AppSpacing.shrink,
        ],
      ),
    );
  }
}
