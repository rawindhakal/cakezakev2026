import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/commons/widgets/app_network_video.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/media_type.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:octo_image/octo_image.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
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

  // Mirrors the resize path build() takes for the same width/height args —
  // height-only ResizeImage when a height is given, box decode for a width
  // alone — so this lands in the image cache under the same key build()
  // will look up later. A mismatched key just decodes the bytes twice for
  // nothing.
  static Future<void> precache(
    BuildContext context,
    String url, {
    double? width,
    double? height,
  }) {
    if (url.isEmpty || !_isValidUrl(url) || _isSvgUrl(url) || isVideoUrl(url)) {
      return Future.value();
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final base = CachedNetworkImageProvider(url);
    final ImageProvider provider = height != null
        ? ResizeImage(
            base,
            height: (height.clamp(1, _maxCacheDimension) * dpr).round(),
          )
        : width != null
        ? _BoxDecodeImage(
            base,
            width: (width.clamp(1, _maxCacheDimension) * dpr).ceil(),
          )
        : base;
    return precacheImage(provider, context);
  }

  static bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.isScheme('HTTP') || uri.isScheme('HTTPS'));
  }

  static bool _isSvgUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.path.toLowerCase().endsWith('.svg');
  }

  // Hard ceiling on decode dimension (logical px) so an oversized source
  // image can never blow past this regardless of KB/MB file size on disk.
  static const double _maxCacheDimension = 1024;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || !_isValidUrl(url)) {
      final empty = errorWidget ?? _placeholder(context);
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: empty)
          : empty;
    }

    // Product media lists mix images and videos in any order, so a video URL
    // can reach any thumbnail — show its first frame instead of a broken image.
    if (isVideoUrl(url)) {
      final video = SizedBox(
        width: width,
        height: height,
        child: AppNetworkVideo(url: url, fit: fit, placeholder: placeholder),
      );
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: video)
          : video;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);

        double? logicalWidth = width;
        if (logicalWidth == null && constraints.maxWidth.isFinite) {
          logicalWidth = constraints.maxWidth;
        }
        double? logicalHeight = height;
        if (logicalHeight == null && constraints.maxHeight.isFinite) {
          logicalHeight = constraints.maxHeight;
        }

        // Only force the hard cap onto BOTH dims when neither is known —
        // that's the unbounded-decode worst case. If one dim is known,
        // leave the other null so the codec keeps aspect ratio.
        final neitherKnown = logicalWidth == null && logicalHeight == null;

        // Both width AND height resizing the decode target only when the
        // caller explicitly asked for both (a deliberate fixed box, where
        // cropping via fit is intended). When both dims were instead derived
        // from the incoming LayoutBuilder constraints (the common
        // grid/card case, where width and height are unrelated to the
        // source image's own aspect ratio), resizing the decode to BOTH
        // distorts the bitmap itself before BoxFit ever runs — so contain
        // ends up "containing" an already-squished image. Cap by width only
        // in that case and let the codec preserve aspect ratio.
        final bothExplicit = width != null && height != null;

        // Never resize BOTH dims (that distorts the bitmap before `fit` runs,
        // the cover bug from 887eca1). When bothExplicit, height alone is
        // used below. Otherwise cap the width alone: leaving it unset decoded
        // every card/banner image at full source resolution, which made
        // scrolling janky. For cover with a known height, decode to the
        // larger box side so a tall box doesn't upscale a wide image.
        /*final coverTarget = fit == BoxFit.cover && logicalHeight != null
            ? (logicalWidth != null && logicalWidth > logicalHeight
                  ? logicalWidth
                  : logicalHeight)
            : logicalWidth;
        final resolvedMemCacheWidth =
            memCacheWidth ??
            (!bothExplicit && logicalWidth != null && coverTarget != null
                ? (coverTarget.clamp(1, _maxCacheDimension) * dpr).round()
                : null);*/
        final resolvedMemCacheHeight =
            memCacheHeight ??
            (logicalHeight != null && (bothExplicit || logicalWidth == null)
                ? (logicalHeight.clamp(1, _maxCacheDimension) * dpr).round()
                : (neitherKnown ? (_maxCacheDimension * dpr).round() : null));

        // No height-based resize applies (width came from the layout), so
        // without this the bitmap was decoded at full source resolution —
        // 3000px+ product/category/banner uploads, ~36MB each, which made
        // grids and carousels raster-heavy. _BoxDecodeImage picks the decode
        // size from the source's real dimensions, so it never distorts and
        // never drops below what the box needs on screen.
        final boxDecode =
            resolvedMemCacheHeight == null &&
            logicalWidth != null &&
            fit != BoxFit.none;

        final img = _isSvgUrl(url)
            ? SvgPicture.network(
                url,
                width: logicalWidth,
                height: logicalHeight,
                fit: fit,
                placeholderBuilder: (_) => placeholder ?? _placeholder(context),
                errorBuilder: (_, _, _) => errorWidget ?? _placeholder(context),
              )
            : boxDecode
            ? OctoImage(
                // Same fade/placeholder defaults CachedNetworkImage hands to
                // OctoImage, so these images look and animate identically.
                image: _BoxDecodeImage(
                  CachedNetworkImageProvider(url),
                  width: (logicalWidth.clamp(1, _maxCacheDimension) * dpr)
                      .ceil(),
                  height: logicalHeight == null
                      ? null
                      : (logicalHeight.clamp(1, _maxCacheDimension) * dpr)
                            .ceil(),
                ),
                width: logicalWidth,
                height: logicalHeight,
                fit: fit,
                filterQuality: FilterQuality.low,
                placeholderBuilder: (_) => placeholder ?? _placeholder(context),
                errorBuilder: (_, _, _) => errorWidget ?? _placeholder(context),
              )
            : CachedNetworkImage(
                imageUrl: url,
                width: logicalWidth,
                height: logicalHeight,
                fit: fit,
                // memCacheWidth: resolvedMemCacheWidth,
                memCacheHeight: resolvedMemCacheHeight,
                placeholder: (_, _) => placeholder ?? _placeholder(context),
                errorWidget: (_, _, _) => errorWidget ?? _placeholder(context),
              );

        if (borderRadius != null) {
          return ClipRRect(borderRadius: borderRadius!, child: img);
        }
        return img;
      },
    );
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
        child: AppSvgIcon(AssetsConstants.placeholder, fit: BoxFit.contain),
      ),
    );
  }
}

/// Decodes [imageProvider] just large enough to cover a [width]×[height]
/// physical-pixel box (or [width] alone when the height is unbounded). The
/// scale is chosen from the source's intrinsic size inside the codec, so the
/// aspect ratio is kept and the result is never smaller than any BoxFit other
/// than `none` draws it — no blur, no stretch — and never upscaled.
@immutable
class _BoxDecodeImage extends ImageProvider<_BoxDecodeKey> {
  const _BoxDecodeImage(this.imageProvider, {required this.width, this.height});

  final ImageProvider<Object> imageProvider;
  final int width;
  final int? height;

  @override
  Future<_BoxDecodeKey> obtainKey(ImageConfiguration configuration) {
    // CachedNetworkImageProvider resolves its key synchronously; then()
    // on a SynchronousFuture stays synchronous, so a cached image still
    // paints on the first frame.
    return imageProvider
        .obtainKey(configuration)
        .then((key) => _BoxDecodeKey(key, width, height));
  }

  @override
  ImageStreamCompleter loadImage(
    _BoxDecodeKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeToBox(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      return decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          var scale = width / intrinsicWidth;
          if (height != null) {
            scale = math.max(scale, height! / intrinsicHeight);
          }
          if (scale >= 1) return const ui.TargetImageSize();
          return ui.TargetImageSize(
            width: (intrinsicWidth * scale).ceil(),
            height: (intrinsicHeight * scale).ceil(),
          );
        },
      );
    }

    return imageProvider.loadImage(key.providerKey, decodeToBox);
  }
}

@immutable
class _BoxDecodeKey {
  const _BoxDecodeKey(this.providerKey, this.width, this.height);

  final Object providerKey;
  final int width;
  final int? height;

  @override
  bool operator ==(Object other) =>
      other is _BoxDecodeKey &&
      other.providerKey == providerKey &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(providerKey, width, height);
}
