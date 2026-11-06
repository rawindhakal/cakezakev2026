import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Square placeholder box shown in place of a missing product/order image.
class ProductImagePlaceholder extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const ProductImagePlaceholder({
    super.key,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: AppDecorations.box(
        color: context.cs.surfaceContainerHigh,
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.4,
        heightFactor: 0.4,
        child: AppSvgIcon(AssetsConstants.placeholder, fit: BoxFit.contain),
      ),
    );
  }
}
