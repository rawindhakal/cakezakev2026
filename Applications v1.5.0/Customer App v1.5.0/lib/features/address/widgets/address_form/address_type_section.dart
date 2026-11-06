import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'flat_section_label.dart';

/// Address type picker, styled as a compact pill row.
class AddressTypeSection extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const AddressTypeSection({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        FlatSectionLabel(context.translate(LanguageLabelKeys.addressType)),
        _TypeChips(selected: selected, onChanged: onChanged),
      ],
    );
  }
}

/// Compact leading pill row — matches the Zomato/Blinkit "save as" selector.
class _TypeChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = [
      (
        'home',
        AssetsConstants.homeIcon,
        context.translate(LanguageLabelKeys.home),
      ),
      (
        'work',
        AssetsConstants.officeIcon,
        context.translate(LanguageLabelKeys.work),
      ),
      (
        'other',
        AssetsConstants.addressIcon,
        context.translate(LanguageLabelKeys.other),
      ),
    ];

    return Row(
      spacing: ThemeConstants.spaceM,
      children: types.map((t) {
        final (value, icon, label) = t;
        final isSelected = selected == value;
        return GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
              vertical: ThemeConstants.paddingS,
            ),
            decoration: AppDecorations.box(
              color: isSelected ? context.cs.primary : context.cs.surface,
              borderRadius: AppRadius.r24,
              border: Border.all(
                color: isSelected
                    ? context.cs.primary
                    : context.cs.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: .min,
              spacing: ThemeConstants.spaceS,
              children: [
                AppSvgIcon(
                  icon,
                  size: ThemeConstants.iconXS,
                  color: isSelected
                      ? context.cs.onPrimary
                      : context.cs.onSurfaceVariant,
                  fit: BoxFit.scaleDown,
                ),
                AppText(
                  label,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? context.cs.onPrimary
                        : context.cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
