import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';

class PulsingPin extends StatelessWidget {
  final Animation<double> animation;

  const PulsingPin({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 20 + 50.0 * v,
                height: 20 + 50.0 * v,
                decoration: AppDecorations.box(
                  shape: .circle,
                  color: context.cs.primary.withValues(alpha: (1 - v) * 0.12),
                ),
              ),
              Container(
                width: 14 + 26.0 * v,
                height: 14 + 26.0 * v,
                decoration: AppDecorations.box(
                  shape: .circle,
                  color: context.cs.primary.withValues(alpha: (1 - v) * 0.22),
                ),
              ),
              AppSvgIcon(
                AssetsConstants.addressIcon,
                color: context.cs.primary,
                size: ThemeConstants.iconXL,
              ),
            ],
          ),
        );
      },
    );
  }
}
