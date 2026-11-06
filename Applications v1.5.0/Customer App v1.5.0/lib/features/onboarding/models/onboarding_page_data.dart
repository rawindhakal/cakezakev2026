import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

class OnboardingPageData {
  final String imagePath;
  final String title;
  final String subtitle;

  const OnboardingPageData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}

List<OnboardingPageData> buildOnboardingPages(BuildContext context) {
  return [
    OnboardingPageData(
      imagePath: AssetsConstants.onBoarding1,
      title: context.translate(LanguageLabelKeys.onboardingTitle1),
      subtitle: context.translate(LanguageLabelKeys.onboardingSubtitle1),
    ),
    OnboardingPageData(
      imagePath: AssetsConstants.onBoarding2,
      title: context.translate(LanguageLabelKeys.onboardingTitle2),
      subtitle: context.translate(LanguageLabelKeys.onboardingSubtitle2),
    ),
    OnboardingPageData(
      imagePath: AssetsConstants.onBoarding3,
      title: context.translate(LanguageLabelKeys.onboardingTitle3),
      subtitle: context.translate(LanguageLabelKeys.onboardingSubtitle3),
    ),
  ];
}
