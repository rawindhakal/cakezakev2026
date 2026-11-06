import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../commons/widgets/app_button.dart';

/// Bottom bar with back/next/submit actions for the edit-profile flow.
class EditProfileBottomNav extends StatelessWidget {
  final int currentStep;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const EditProfileBottomNav({
    super.key,
    required this.currentStep,
    required this.isLoading,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        12 + context.bottomSafePadding,
      ),
      decoration: AppDecorations.card(
        color: context.cs.surface,
        boxShadow: [
          BoxShadow(
            color: context.cs.scrim.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        spacing: ThemeConstants.spaceM,
        children: [
          Expanded(
            child: AppButton(
              label: currentStep == 0
                  ? context.translate(LanguageLabelKeys.cancel)
                  : context.translate(LanguageLabelKeys.back),
              variant: AppButtonVariant.outline,
              color: context.cs.onSurfaceVariant,
              height: context.screenHeight * 0.062,
              onPressed: isLoading ? null : onBack,
            ),
          ),
          Expanded(
            child: currentStep == 0
                ? AppButton(
                    label: context.translate(LanguageLabelKeys.next),
                    height: context.screenHeight * 0.062,
                    onPressed: onNext,
                  )
                : AppButton(
                    label: context.translate(LanguageLabelKeys.updateProfile),
                    height: context.screenHeight * 0.062,
                    onPressed: onSubmit,
                    isLoading: isLoading,
                  ),
          ),
        ],
      ),
    );
  }
}
