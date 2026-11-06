import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/commons/widgets/app_radio_option_tile.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/spin_wheel/models/spin_reward_filter_type.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Bottom sheet with the 4 `reward_type` choices for [SpinWheelRewardsScreen]
/// (spin_wheel_rewards_screen.dart) — All / Wallet / Promo Code / Free
/// Delivery — same single-choice radio-list shape as `showProductSortSheet`.
void showSpinWheelRewardFilterSheet(
  BuildContext context,
  SpinRewardFilterType current, {
  required ValueChanged<SpinRewardFilterType> onSelect,
}) {
  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.filterByType),
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingL,
      ThemeConstants.paddingXXL,
    ),
    enableDrag: true,
    builder: (sheetContext) => _SpinWheelRewardFilterSheet(
      current: current,
      onSelect: (type) {
        onSelect(type);
        AppNavigator.pop(sheetContext);
      },
    ),
  );
}

class _SpinWheelRewardFilterSheet extends StatelessWidget {
  final SpinRewardFilterType current;
  final ValueChanged<SpinRewardFilterType> onSelect;

  const _SpinWheelRewardFilterSheet({
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final types = SpinRewardFilterType.values;
    return RadioGroup<SpinRewardFilterType>(
      groupValue: current,
      onChanged: (type) {
        if (type != null) onSelect(type);
      },
      child: SlideAnimationList(
        children: [
          for (final type in types)
            AppRadioOptionTile<SpinRewardFilterType>(
              value: type,
              title: context.translate(type.labelKey()),
              selected: type == current,
              showContainerDecoration: false,
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingM,
              ),
              onTap: () => onSelect(type),
            ),
        ],
      ),
    );
  }
}
