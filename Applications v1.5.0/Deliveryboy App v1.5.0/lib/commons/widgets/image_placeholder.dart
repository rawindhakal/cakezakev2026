import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';

/// Shared square fallback shown in place of a missing/failed item image.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    required this.size,
    this.borderRadius = AppRadius.r10,
    this.iconSize = 24,
  });

  final double size;
  final BorderRadius borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: AppDecorations.card(
      color: context.cs.surfaceContainerLow,
      borderRadius: borderRadius,
    ),
    child: FractionallySizedBox(
      widthFactor: 0.4,
      heightFactor: 0.4,
      child: AppSvgIcon(AssetsConstants.placeholder, fit: .contain),
    ),
  );
}
