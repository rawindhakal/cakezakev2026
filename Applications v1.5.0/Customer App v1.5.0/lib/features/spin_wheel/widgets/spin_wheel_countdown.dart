import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// "Next Spin In  HH : MM : SS" countdown, shown in the board's tray in place
/// of the SPIN button while the daily spin quota is used up.
///
/// It listens to [remaining] itself, so the once-a-second tick rebuilds only
/// this small widget and not the whole dialog (wheel included).
class SpinWheelCountdown extends StatelessWidget {
  final ValueListenable<Duration> remaining;

  const SpinWheelCountdown({super.key, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.nextSpinIn),
          style: context.tt.labelMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ThemeConstants.spaceXS),
        ValueListenableBuilder<Duration>(
          valueListenable: remaining,
          builder: (context, value, _) {
            String two(int n) => n.toString().padLeft(2, '0');
            return Row(
              mainAxisSize: MainAxisSize.min,
              spacing: ThemeConstants.spaceXS,
              children: [
                _DigitTile(two(value.inHours)),
                const _Separator(),
                _DigitTile(two(value.inMinutes % 60)),
                const _Separator(),
                _DigitTile(two(value.inSeconds % 60)),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One dark flip-clock style tile showing a two-digit value, with a seam line
/// across the middle.
class _DigitTile extends StatelessWidget {
  final String value;

  const _DigitTile(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingS,
        vertical: ThemeConstants.paddingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.black87,
        borderRadius: AppRadius.r8,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.15)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppText(
            value,
            style: context.tt.titleMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              // Fixed-width digits so the tiles don't jiggle as they change.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Container(height: 1, color: AppColors.black54),
        ],
      ),
    );
  }
}

/// The ":" between two digit tiles.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return AppText(
      ':',
      style: context.tt.titleMedium?.copyWith(
        color: context.cs.onPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
