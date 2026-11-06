import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OnboardingDots extends StatelessWidget {
  final int count;
  final double page;
  final Color activeColor;
  final Color inactiveColor;

  const OnboardingDots({
    super.key,
    required this.count,
    required this.page,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = page.round().clamp(0, count - 1);
    return Row(
      mainAxisSize: .min,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsetsDirectional.only(
            end: ThemeConstants.paddingXS,
          ),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: AppDecorations.box(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: AppRadius.r4,
          ),
        );
      }),
    );
  }
}
