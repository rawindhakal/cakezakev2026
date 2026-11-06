import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Small, muted notice shown only when the backend flags `demo_mode`.
/// Kept low-contrast on purpose — informational, not a warning.
class DemoDataDisclaimer extends StatelessWidget {
  const DemoDataDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurfaceMuted = context.cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingL,
        vertical: ThemeConstants.paddingS,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingM,
        ),
        decoration: AppDecorations.box(
          color: context.cs.surfaceContainerHigh,
          borderRadius: AppRadius.r8,
          border: Border.all(color: context.cs.outline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              LanguageLabelKeys.demoDataDisclaimerTitle,
              style: context.tt.labelSmall?.copyWith(
                color: onSurfaceMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            AppText(
              LanguageLabelKeys.demoDataDisclaimerBody,
              style: context.tt.labelSmall?.copyWith(
                color: onSurfaceMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
