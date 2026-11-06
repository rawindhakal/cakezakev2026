import 'package:flutter/material.dart';

/// Common widget for rendering PNG asset icons, mirroring [AppSvgIcon]'s API.
class AppPngIcon extends StatelessWidget {
  final String path;

  /// Explicit square size. Null = unconstrained (natural size).
  final double? size;

  final BoxFit fit;

  const AppPngIcon(
    this.path, {
    super.key,
    this.size,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(path, width: size, height: size, fit: fit);
  }
}
