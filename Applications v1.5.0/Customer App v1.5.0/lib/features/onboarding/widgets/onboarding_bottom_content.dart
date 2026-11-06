import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/onboarding/widgets/onboarding_dots.dart';
import 'package:customer/features/onboarding/widgets/onboarding_next_button.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

class OnboardingBottomContent extends StatelessWidget {
  final double page;
  final int pageCount;
  final bool isLast;
  final VoidCallback onNext;

  const OnboardingBottomContent({
    super.key,
    required this.page,
    required this.pageCount,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = AppSizes.onboardingCardPaddingH(context);
    final btnHeight = AppSizes.onboardingButtonSize(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(
        hPad,
        ThemeConstants.paddingL,
        hPad,
        context.bottomSafePadding + ThemeConstants.paddingL,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceXL,
        children: [
          OnboardingDots(
            count: pageCount,
            page: page,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor: Theme.of(context).colorScheme.outline,
          ),
          OnboardingNextButton(
            isLast: isLast,
            onTap: onNext,
            height: btnHeight,
          ),
        ],
      ),
    );
  }
}
