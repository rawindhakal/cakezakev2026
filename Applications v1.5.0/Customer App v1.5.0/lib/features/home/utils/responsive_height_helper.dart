import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

class ResponsiveHeightHelper {
  static const double _minHeight = 80.0;
  static const double _maxHeight = 600.0;

  /// [renderWidth] must be the actual width the image will render at (e.g.
  /// screenWidth * viewportFraction for carousel styles that only show a
  /// fraction of the screen per item) — using the full screen width here for
  /// those styles produces a height proportioned for a wider image than the
  /// item actually is, forcing BoxFit.cover to crop heavily on tablets.
  /// [imageAspect] expected as "width:height" string, e.g. "16:9".
  static double calculateFromAspect({
    required String? imageAspect,
    required BuildContext context,
    double? renderWidth,
  }) {
    final ratio = parseAspectRatio(imageAspect);
    if (ratio == null) {
      return _getDefaultHeight(context);
    }

    final width = renderWidth ?? context.screenWidth;
    final calculatedHeight = width / ratio;

    return calculatedHeight.clamp(_minHeight, _maxHeight);
  }

  /// Returns width/height ratio from a "width:height" string, e.g. "16:9" → 1.78.
  static double? parseAspectRatio(String? imageAspect) {
    if (imageAspect == null || imageAspect.isEmpty) return null;

    final parts = imageAspect.split(':');
    if (parts.length != 2) return null;

    final w = double.tryParse(parts[0].trim());
    final h = double.tryParse(parts[1].trim());
    if (w == null || h == null || w <= 0 || h <= 0) return null;

    return w / h;
  }

  static double _getDefaultHeight(BuildContext context) {
    final screenHeight = context.screenHeight;
    if (screenHeight < 600) {
      return 200;
    } else if (screenHeight < 900) {
      return 250;
    } else {
      return 300;
    }
  }
}
