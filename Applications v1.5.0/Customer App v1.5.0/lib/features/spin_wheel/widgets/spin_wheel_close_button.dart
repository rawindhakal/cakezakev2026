import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Round "X" button that closes the spin dialog: a dark glass circle with a
/// light grey rim and a white icon. Sized from the screen width, capped so it
/// doesn't grow on tablets.
class SpinWheelCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const SpinWheelCloseButton({super.key, required this.onTap});

  static const _maxSize = 34.0;
  static const _sizeFraction = 0.075; // of screen width, ~30px on a phone

  @override
  Widget build(BuildContext context) {
    final size = context.widthFraction(_sizeFraction).clamp(0.0, _maxSize);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: AppDecorations.box(
          color: context.cs.scrim.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: context.cs.onPrimary.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: AppSvgIcon(
          AssetsConstants.closeIcon,
          color: context.cs.onPrimary,
          size: ThemeConstants.iconXS,
        ),
      ),
    );
  }
}
