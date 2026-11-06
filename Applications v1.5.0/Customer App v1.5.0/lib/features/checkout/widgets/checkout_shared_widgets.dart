import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CheckoutCard extends StatelessWidget {
  const CheckoutCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CheckoutSectionHeader extends StatelessWidget {
  const CheckoutSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final String icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceS,
      children: [
        icon.isNotEmpty
            ? AppSvgIcon(
                icon,
                color: context.cs.onSurfaceVariant,
                size: ThemeConstants.iconM,
              )
            : const SizedBox(),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXXS,
            children: [
              AppText(
                title,
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                AppText(
                  subtitle!,
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown in the checkout body when the selected address is outside every
/// serviceable zone (is_deliverable_address == 0). Replaces promo/wallet/note/
/// bill sections with a clear "we don't deliver here" notice.
class CheckoutNotDeliverableNotice extends StatelessWidget {
  const CheckoutNotDeliverableNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: AppDecorations.box(
              color: context.cs.error.withValues(alpha: 0.1),
              borderRadius: AppRadius.r10,
            ),
            child: AppSvgIcon(
              AssetsConstants.locationOffIcon,
              size: ThemeConstants.iconM,
              color: context.cs.error,
            ),
          ),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.zoneUnavailableTitle),
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                AppSpacing.h4,
                AppText(
                  context.translate(LanguageLabelKeys.zoneUnavailableSubtitle),
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
