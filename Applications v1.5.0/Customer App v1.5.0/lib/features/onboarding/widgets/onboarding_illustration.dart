import 'package:customer/features/onboarding/models/onboarding_page_data.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';

class OnboardingIllustration extends StatelessWidget {
  final OnboardingPageData page;
  final AnimationController animationController;
  final double outerSize;

  const OnboardingIllustration({
    super.key,
    required this.page,
    required this.animationController,
    this.outerSize = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const AlignmentDirectional(0, 0.85),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingXXL * 2,
          0,
          ThemeConstants.paddingXXL * 2,
          0,
        ),
        child: SlideAnimation(
          position: 0,
          itemCount: 2,
          slideDirection: SlideDirection.fromBottom,
          animationController: animationController,
          child: AppSvgIcon(
            page.imagePath,
            size: outerSize * 1.6,
            fit: BoxFit.contain,
            useColorMapper: true,
            color: context.cs.primary,
          ),
        ),
      ),
    );
  }
}
