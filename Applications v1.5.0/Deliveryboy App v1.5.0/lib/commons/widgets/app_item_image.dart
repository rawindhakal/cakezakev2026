import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/image_placeholder.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:flutter/material.dart';

/// Square product/item thumbnail with a shared rounded placeholder fallback.
///
/// Wraps [AppNetworkImage] with the same [ImagePlaceholder] used for both the
/// loading and error states, clipped to [borderRadius]. When [url] is missing
/// (null, empty, or the literal string `'null'`) the placeholder is shown
/// directly. Used across the order/ecommerce item cards which previously
/// duplicated this `ClipRRect` + placeholder wiring.
class AppItemImage extends StatelessWidget {
  final String? url;
  final double size;
  final BorderRadius borderRadius;
  final double iconSize;

  const AppItemImage({
    super.key,
    required this.url,
    required this.size,
    this.borderRadius = AppRadius.r10,
    this.iconSize = ThemeConstants.iconL,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = ImagePlaceholder(
      size: size,
      borderRadius: borderRadius,
      iconSize: iconSize,
    );
    final hasImage = url != null && url!.isNotEmpty && url != 'null';
    return ClipRRect(
      borderRadius: borderRadius,
      child: hasImage
          ? AppNetworkImage(
              url: url!,
              width: size,
              height: size,
              fit: .cover,
              placeholder: placeholder,
              errorWidget: placeholder,
            )
          : placeholder,
    );
  }
}
