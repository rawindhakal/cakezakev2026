import 'package:cached_network_image/cached_network_image.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Cached network image with a shared placeholder/error fallback icon.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = .cover,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorIconSize = 24.0,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final double errorIconSize;
  final Widget? placeholder;
  final Widget? errorWidget;

  static ImageProvider provider(String url) => CachedNetworkImageProvider(url);

  static bool _isSvgUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.path.toLowerCase().endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      final empty = errorWidget ?? _placeholder(context);
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: empty)
          : empty;
    }

    final img = _isSvgUrl(url)
        ? SvgPicture.network(
            url,
            width: width,
            height: height,
            fit: fit,
            placeholderBuilder: (_) => placeholder ?? _placeholder(context),
            errorBuilder: (_, _, _) => errorWidget ?? _placeholder(context),
          )
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            placeholder: (_, _) => placeholder ?? _placeholder(context),
            errorWidget: (_, _, _) => errorWidget ?? _placeholder(context),
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.4,
        heightFactor: 0.4,
        child: AppSvgIcon(AssetsConstants.placeholder, fit: .contain),
      ),
    );
  }
}
