import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Shared "Add new address" row — used by the address picker sheet and the
/// address list screen so both trigger the same add-address flow with the
/// same look.
class AddNewAddressButton extends StatelessWidget {
  const AddNewAddressButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.surface,
      borderRadius: AppRadius.r12,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.r12,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingM,
            vertical: ThemeConstants.paddingM,
          ),
          decoration: AppDecorations.box(
            borderRadius: AppRadius.r12,
            border: Border.all(
              color: context.cs.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              AppSvgIcon(
                AssetsConstants.addIcon,
                color: context.cs.primary,
                size: ThemeConstants.iconM,
              ),
              AppSpacing.w10,
              Expanded(
                child: AppText(
                  context.translate(LanguageLabelKeys.addNewAddress),
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.cs.primary,
                  ),
                ),
              ),
              Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: AppSvgIcon(
                  AssetsConstants.arrowRightIcon,
                  color: context.cs.onSurfaceVariant,
                  size: ThemeConstants.iconM,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
