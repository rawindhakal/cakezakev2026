import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OnboardingSkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const OnboardingSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: AppRadius.r20,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.r20,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
            vertical: ThemeConstants.paddingS,
          ),
          child: AppText(
            context.translate(LanguageLabelKeys.skip),
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
