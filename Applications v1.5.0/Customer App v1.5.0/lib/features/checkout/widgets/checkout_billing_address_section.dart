import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/checkout/models/billing_address_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

/// Compact "billing address same as shipping" checkbox strip — sits inside
/// [CheckoutPlaceOrderBar], directly below the address strip, so it reads as
/// part of the same bottom-bar chrome rather than a separate scrollable card.
class CheckoutBillingAddressSection extends StatelessWidget {
  const CheckoutBillingAddressSection({
    super.key,
    required this.sameAsShipping,
    required this.billingAddress,
    required this.onToggle,
    required this.onEdit,
  });

  final bool sameAsShipping;
  final BillingAddressData? billingAddress;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.only(
        start: ThemeConstants.paddingL,
        end: ThemeConstants.paddingL,
        bottom: ThemeConstants.paddingS,
      ),
      // Flat rectangle, no radius of its own — sits flush beneath
      // [_AddressStrip] (same surfaceContainerLow color, rounded top only)
      // so the two fuse into a single continuous card.
      color: context.cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Divider(
            height: ThemeConstants.paddingXS,
            thickness: 0.5,
            color: context.cs.outline.withValues(alpha: 0.15),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onToggle(!sameAsShipping),
            child: Row(
              children: [
                _BillingCheckbox(selected: sameAsShipping),
                AppSpacing.w10,
                Expanded(
                  child: AppText(
                    context.translate(LanguageLabelKeys.billingSameAsShipping),
                    style: context.tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!sameAsShipping)
                  GestureDetector(
                    onTap: onEdit,
                    child: AppText(
                      context.translate(
                        billingAddress == null
                            ? LanguageLabelKeys.add
                            : LanguageLabelKeys.change,
                      ),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!sameAsShipping && billingAddress != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: ThemeConstants.paddingXS,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 22 + ThemeConstants.paddingS),
                  Expanded(
                    child: AppText(
                      '${billingAddress!.name} • ${billingAddress!.address}, ${billingAddress!.city}',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
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

class _BillingCheckbox extends StatelessWidget {
  const _BillingCheckbox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: AppDecorations.box(
        color: selected ? context.cs.primary : Colors.transparent,
        borderRadius: AppRadius.r4,
        border: Border.all(
          color: selected ? context.cs.primary : context.cs.onSurfaceVariant,
          width: 1.5,
        ),
      ),
      child: selected
          ? AppSvgIcon(
              AssetsConstants.checkIcon,
              size: ThemeConstants.iconXS,
              color: context.cs.onPrimary,
            )
          : null,
    );
  }
}
