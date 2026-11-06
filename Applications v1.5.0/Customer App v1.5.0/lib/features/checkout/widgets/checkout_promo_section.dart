import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/features/promo_code/models/enums/promo_discount_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CheckoutPromoSection extends StatelessWidget {
  const CheckoutPromoSection({
    super.key,
    required this.appliedPromo,
    required this.onRemove,
    required this.onBrowseCodes,
    this.unlockMessage,
    this.unlockPromoCode,
  });

  final PromoCodeData? appliedPromo;
  final VoidCallback onRemove;
  final VoidCallback onBrowseCodes;
  final String? unlockMessage;
  final String? unlockPromoCode;

  @override
  Widget build(BuildContext context) {
    final promo = appliedPromo;
    final isApplied = promo != null;
    final isUnlocked = !isApplied && (unlockMessage?.isNotEmpty ?? false);

    return CheckoutCard(
      child: InkWell(
        borderRadius: AppRadius.r12,
        onTap: (!isApplied && !isUnlocked) ? onBrowseCodes : null,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .center,
              children: [
                _PromoTileIcon(
                  isApplied: isApplied,
                  color: context.cs.onSecondaryContainer,
                ),
                AppSpacing.w12,
                Expanded(
                  child: isApplied
                      ? _AppliedText(promo: promo)
                      : _UnappliedText(
                          isUnlocked: isUnlocked,
                          unlockMessage: unlockMessage,
                          unlockPromoCode: unlockPromoCode,
                        ),
                ),
                AppSpacing.w8,
                if (isApplied)
                  _RemoveButton(onTap: onRemove)
                else if (isUnlocked)
                  _ApplyPill(onTap: onBrowseCodes)
                else
                  Transform.flip(
                    flipX: Directionality.of(context) == TextDirection.rtl,
                    child: AppSvgIcon(
                      AssetsConstants.arrowRightIcon,
                      color: context.cs.onSurfaceVariant,
                      size: ThemeConstants.iconL,
                    ),
                  ),
              ],
            ),
            if (isApplied || isUnlocked) ...[
              AppSpacing.h12,
              Divider(height: 1, color: context.cs.outlineVariant),
              AppSpacing.h10,
              InkWell(
                onTap: onBrowseCodes,
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        context.translate(LanguageLabelKeys.viewAllCoupons),
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: AppSvgIcon(
                        AssetsConstants.arrowRightIcon,
                        size: ThemeConstants.iconXS,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppliedText extends StatelessWidget {
  const _AppliedText({required this.promo});

  final PromoCodeData promo;

  @override
  Widget build(BuildContext context) {
    final isFreeDelivery =
        promo.discountTypeEnum == PromoDiscountType.freeDelivery;
    if (isFreeDelivery) {
      return AppText(
        "${context.translate(LanguageLabelKeys.freeDeliveryApplied)} ${context.translate(LanguageLabelKeys.withCode)} '${promo.promoCode}'",
        style: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.cs.onSurface,
        ),
      );
    }
    return AppText(
      "${context.translate(LanguageLabelKeys.youSaved)} ${promo.currency}${promo.discount.formatPrice(promo.decimalPoint)} ${context.translate(LanguageLabelKeys.withCode)} '${promo.promoCode}'",
      style: context.tt.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.cs.onSurface,
      ),
    );
  }
}

class _UnappliedText extends StatelessWidget {
  const _UnappliedText({
    required this.isUnlocked,
    required this.unlockMessage,
    required this.unlockPromoCode,
  });

  final bool isUnlocked;
  final String? unlockMessage;
  final String? unlockPromoCode;

  @override
  Widget build(BuildContext context) {
    if (!isUnlocked) {
      return AppText(
        context.translate(LanguageLabelKeys.viewAllCoupons),
        style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      );
    }
    return Column(
      crossAxisAlignment: .start,
      children: [
        if (unlockPromoCode != null && unlockPromoCode!.isNotEmpty)
          AppText(
            '${context.translate(LanguageLabelKeys.unlock)} $unlockPromoCode',
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
        AppText(
          unlockMessage!,
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingXS,
          vertical: 2,
        ),
        child: AppText(
          context.translate(LanguageLabelKeys.remove),
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ApplyPill extends StatelessWidget {
  const _ApplyPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingXS,
        ),
        decoration: AppDecorations.box(
          color: context.cs.primary,
          borderRadius: AppRadius.r8,
        ),
        child: AppText(
          context.translate(LanguageLabelKeys.apply).toUpperCase(),
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _PromoTileIcon extends StatelessWidget {
  const _PromoTileIcon({required this.isApplied, required this.color});

  final bool isApplied;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return isApplied
        ? AppSvgIcon(
            AssetsConstants.checkCircleIcon,
            size: ThemeConstants.iconL,
            color: color,
          )
        : AppSvgIcon(
            AssetsConstants.discountCouponsIcon,
            size: ThemeConstants.iconL,
            color: color,
          );
  }
}
