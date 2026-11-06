import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';

/// 0=none | 1=veg | 2=non-veg | 3=chemical | 4=eggetarian | 5=medical
class ProductTypeIcon extends StatelessWidget {
  final int? productType;
  final double size;

  const ProductTypeIcon({super.key, this.productType, this.size = 18});

  static const double inlineGap = 4;

  static bool hasIcon(int? productType) => (productType ?? 0) != 0;

  /// [name] with the mark inline before it — wrapped lines start under the
  /// icon instead of indenting beside it. Nothing extra for product_type 0.
  static InlineSpan nameSpan({
    required int? productType,
    required String name,
    required double size,
  }) {
    return TextSpan(
      children: [
        if (hasIcon(productType))
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: inlineGap),
              child: ProductTypeIcon(productType: productType, size: size),
            ),
          ),
        TextSpan(text: name),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (productType) {
      case 1:
        return AppSvgIcon(AssetsConstants.vegIcon, size: size);
      case 2:
        return AppSvgIcon(AssetsConstants.nonVegIcon, size: size);
      case 3:
        return AppSvgIcon(AssetsConstants.chemicalIcon, size: size);
      case 4:
        return AppSvgIcon(AssetsConstants.eggetarianIcon, size: size);
      case 5:
        return AppSvgIcon(AssetsConstants.medicalIcon, size: size);
      default:
        return const SizedBox.shrink();
    }
  }
}
