import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/onboarding/models/onboarding_page_data.dart';
import 'package:customer/features/onboarding/widgets/onboarding_illustration.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class OnboardingPageContent extends StatelessWidget {
  final OnboardingPageData page;
  final AnimationController animationController;
  final double bottomReservedHeight;

  const OnboardingPageContent({
    super.key,
    required this.page,
    required this.animationController,
    required this.bottomReservedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: OnboardingIllustration(
                page: page,
                animationController: animationController,
                outerSize: AppSizes.onboardingOuterSize(context),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSizes.onboardingCardPaddingH(context),
                0,
                AppSizes.onboardingCardPaddingH(context),
                bottomReservedHeight,
              ),
              child: SlideAnimation(
                position: 1,
                itemCount: 2,
                slideDirection: SlideDirection.fromBottom,
                animationController: animationController,
                child: Column(
                  crossAxisAlignment: .center,
                  spacing: ThemeConstants.spaceS,
                  children: [
                    AppText(
                      page.title,
                      textAlign: .center,
                      style: context.tt.headlineSmall?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        color: context.cs.onSurface,
                        height: 1.25,
                      ),
                    ),
                    AppText(
                      page.subtitle,
                      textAlign: .center,
                      style: context.tt.bodyLarge?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
