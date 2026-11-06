import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

class OnboardingNextButton extends StatelessWidget {
  final bool isLast;
  final VoidCallback onTap;
  final double height;

  const OnboardingNextButton({
    super.key,
    required this.isLast,
    required this.onTap,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      onPressed: onTap,
      height: height,
      label: context.translate(
        isLast ? LanguageLabelKeys.getStarted : LanguageLabelKeys.next,
      ),
    );
  }
}
