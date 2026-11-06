import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/extensions/context_extensions.dart';

/// 5-star row rendering full/half/empty stars for a `rating` value (0-5).
///
/// By default empty stars stay the same [color] as filled ones (matches
/// product card/list star rows). Pass [outlineColor] to dim empty stars
/// instead (matches the product-detail rating summary).
///
/// Pass [onStarTap] to make it an interactive tap-to-rate input instead of a
/// read-only summary — stars render as whole filled/empty (no half-star) and
/// each is wrapped in a tap target reporting the 1-based star index.
class StarRatingRow extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  final Color? outlineColor;
  final double halfThreshold;
  final ValueChanged<int>? onStarTap;
  final bool enabled;

  const StarRatingRow({
    super.key,
    required this.rating,
    this.size = 16,
    this.color,
    this.outlineColor,
    this.halfThreshold = 0.5,
    this.onStarTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? context.cs.onPrimaryFixedVariant;
    final isInteractive = onStarTap != null;

    return Row(
      mainAxisSize: .min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor() || (isInteractive && i < rating);
        final half =
            !isInteractive &&
            !filled &&
            i < rating &&
            (rating - i) >= halfThreshold;
        final icon = AppSvgIcon(
          filled
              ? AssetsConstants.starFillIcon
              : half
              ? AssetsConstants.starHalfFillIcon
              : AssetsConstants.starBorderIcon,
          size: size,
          color: filled || half || outlineColor == null
              ? starColor
              : outlineColor,
          bakeTint: true,
        );

        if (!isInteractive) return icon;

        return IconButton(
          onPressed: enabled ? () => onStarTap!(i + 1) : null,
          icon: icon,
        );
      }),
    );
  }
}
