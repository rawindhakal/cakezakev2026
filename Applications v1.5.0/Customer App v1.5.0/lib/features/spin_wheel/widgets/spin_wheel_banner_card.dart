import 'dart:math' as math;

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/spin_wheel/widgets/animated_spin_wheel.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_dialog.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// Banner card: title, description, "Spin Now" button and a wheel on the
/// trailing side. Tapping the button opens the spin wheel dialog.
class SpinWheelBannerCard extends StatelessWidget {
  const SpinWheelBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    const double wheelSize = 150;
    // ~70% of the wheel shows: past the halfway line so the whole center
    // SPIN hub stays visible, while the rest is clipped by the card's edge.
    const double visibleWidth = wheelSize * 0.7;
    return Container(
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: ThemeConstants.paddingL,
              end: visibleWidth + ThemeConstants.paddingS,
              top: ThemeConstants.paddingL,
              bottom: ThemeConstants.paddingL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.getFreeWalletCash),
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  context.translate(LanguageLabelKeys.spinWheelPromoDesc),
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: context.translate(LanguageLabelKeys.spinNow),
                  fullWidth: false,
                  height: 38,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 28,
                  ),
                  borderRadius: AppRadius.r12,
                  onPressed: () => SpinWheelDialog.show(context),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            end: visibleWidth - wheelSize,
            // Pushed down so the bottom is clipped by the card too.
            bottom: -wheelSize * 0.25,
            child: Center(
              child: AnimatedSpinWheel(
                hexColor:
                    '#${context.cs.primary.toARGB32().toRadixString(16).padLeft(8, '0')}',
                size: wheelSize,
                segmentCount: 12,
                pointerAngle: Directionality.of(context) == TextDirection.rtl
                    ? math.pi / 4
                    : -math.pi / 4,
                centerLabel: context.translate(
                  LanguageLabelKeys.spinButtonLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
