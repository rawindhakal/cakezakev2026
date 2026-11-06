import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/promo_code/models/enums/promo_apply_type.dart';
import 'package:customer/features/promo_code/models/enums/promo_discount_type.dart';
import 'package:customer/features/spin_wheel/models/spin_reward_filter_type.dart';
import 'package:customer/features/spin_wheel/models/spin_wheel_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// One row in the "My Rewards" history list ([SpinWheelRewardsScreen]):
/// icon, label, won-on date, a human-readable discount/min-order/validity
/// summary, a copyable promo code (when the reward is one), and the amount.
/// Fades and slides in on first build so the list doesn't pop in flatly.
class SpinWheelRewardTile extends StatefulWidget {
  final SpinReward reward;
  const SpinWheelRewardTile({super.key, required this.reward});

  @override
  State<SpinWheelRewardTile> createState() => _SpinWheelRewardTileState();
}

class _SpinWheelRewardTileState extends State<SpinWheelRewardTile>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyPromoCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    final promo = reward.promoCode;
    final isPromoCodeReward =
        reward.rewardType.trim().toLowerCase() ==
        SpinRewardFilterType.promoCode.apiValue;
    final isExpired = isPromoCodeReward && (promo?.isExpired ?? false);
    final promoCode = promo?.promoCode;
    final discount = promo?.discount.toDouble() ?? 0;
    final discountTypeEnum = PromoDiscountType.fromRaw(promo?.discountType);
    final rewardTypeLabelKey = switch (reward.rewardType.trim().toLowerCase()) {
      final t when t == SpinRewardFilterType.wallet.apiValue =>
        LanguageLabelKeys.walletReward,
      // Promo codes credited to the wallet after delivery are cashback;
      // ones applied straight to the bill at checkout are an instant
      // discount — mirrors PromoApplyType's use in the checkout bill.
      final t when t == SpinRewardFilterType.promoCode.apiValue =>
        promo?.discountApplyTypeEnum == PromoApplyType.wallet
            ? LanguageLabelKeys.cashback
            : LanguageLabelKeys.instantDiscount,
      final t when t == SpinRewardFilterType.freeDelivery.apiValue =>
        LanguageLabelKeys.freeDelivery,
      _ => null,
    };

    // Human-readable discount summary — mirrors PromoCodeTileWidget's own
    // "Flat ₹X off" / "X% off (Max ₹Y)" phrasing, plus the free-delivery
    // case that promo codes screen doesn't need to handle.
    final discountText = discountTypeEnum == PromoDiscountType.freeDelivery
        ? context.translate(LanguageLabelKeys.freeDelivery)
        : discount > 0
        ? (discountTypeEnum == PromoDiscountType.flat
              ? '${context.translate(LanguageLabelKeys.flatDiscount)} ${reward.currency}${discount.toStringAsFixed(discount.truncateToDouble() == discount ? 0 : 1)} ${context.translate(LanguageLabelKeys.off)}'
              : '${discount.toStringAsFixed(discount.truncateToDouble() == discount ? 0 : 1)}${AppConstants.percentSymbol} ${context.translate(LanguageLabelKeys.off)}'
                    '${(promo?.maxDiscountAmount ?? 0) > 0 ? ' (${context.translate(LanguageLabelKeys.maxDiscount)} ${reward.currency}${promo!.maxDiscountAmount.toStringAsFixed(0)})' : ''}')
        : '';
    final minOrderText = (promo?.minimumOrderAmount ?? 0) > 0
        ? '${context.translate(LanguageLabelKeys.minOrder)} ${reward.currency}${promo!.minimumOrderAmount.toStringAsFixed(0)}'
        : '';
    final validTillText = (promo?.endDateLabel.isNotEmpty ?? false)
        ? '${context.translate(LanguageLabelKeys.validTill)} ${promo!.endDateLabel}'
        : '';
    final detailLines = [
      discountText,
      minOrderText,
      validTillText,
    ].where((e) => e.isNotEmpty).toList();

    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 16 * (1 - _fade.value)),
          child: child,
        ),
        child: Opacity(
          opacity: isExpired ? 0.55 : 1,
          child: Container(
            margin: const EdgeInsetsDirectional.only(
              bottom: ThemeConstants.paddingM,
            ),
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
            decoration: AppDecorations.shadowedCard(
              color: isExpired
                  ? context.cs.surfaceContainerLow
                  : context.cs.surface,
              shadowColor: context.cs.shadow.withValues(alpha: 0.08),
            ),
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceM,
              children: [
                Row(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceM,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsetsDirectional.all(
                        ThemeConstants.paddingXS,
                      ),
                      decoration: AppDecorations.box(
                        color: context.cs.onSurfaceVariant.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppNetworkImage(
                        url: reward.iconUrl,
                        borderRadius: AppRadius.r8,
                        errorWidget: Icon(
                          Icons.card_giftcard,
                          color: context.cs.onSurfaceVariant,
                          size: ThemeConstants.iconM,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: ThemeConstants.spaceXS,
                        children: [
                          Row(
                            crossAxisAlignment: .start,
                            spacing: ThemeConstants.spaceS,
                            children: [
                              Expanded(
                                child: AppText(
                                  reward.label,
                                  style: context.tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.cs.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isExpired)
                                Container(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                        horizontal: ThemeConstants.paddingXS,
                                        vertical: 2,
                                      ),
                                  decoration: BoxDecoration(
                                    color: context.cs.error.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: AppText(
                                    context.translate(
                                      LanguageLabelKeys.expired,
                                    ),
                                    style: context.tt.labelSmall?.copyWith(
                                      color: context.cs.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              // Won-on date here (amount's old spot) — amount
                              // moved down to the bottom row where this date
                              // used to sit.
                              AppText(
                                reward.wonAtLabel,
                                style: context.tt.labelSmall?.copyWith(
                                  color: context.cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (reward.campaignName.isNotEmpty)
                            AppText(
                              reward.campaignName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (detailLines.isNotEmpty)
                  AppText(
                    detailLines.join('  •  '),
                    style: context.tt.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                if (promoCode != null && promoCode.isNotEmpty)
                  InkWell(
                    onTap: isExpired
                        ? null
                        : () => _copyPromoCode(context, promoCode),
                    borderRadius: AppRadius.r8,
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingS,
                      ),
                      decoration: AppDecorations.outlinedCard(
                        color: context.cs.surfaceContainerLow,
                        borderColor: context.cs.outlineVariant,
                        borderRadius: 8,
                      ),
                      child: Row(
                        spacing: ThemeConstants.spaceS,
                        children: [
                          Expanded(
                            child: AppText(
                              promoCode,
                              style: context.tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: context.cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppSvgIcon(
                            AssetsConstants.copyIcon,
                            size: ThemeConstants.iconS,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (reward.amount > 0)
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      if (rewardTypeLabelKey != null)
                        AppText(
                          context.translate(rewardTypeLabelKey),
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      AppText(
                        '${reward.currency}${reward.amount}',
                        style: context.tt.titleSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
