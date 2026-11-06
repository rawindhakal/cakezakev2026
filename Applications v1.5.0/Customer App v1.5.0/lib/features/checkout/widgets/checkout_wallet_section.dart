import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CheckoutWalletSection extends StatelessWidget {
  const CheckoutWalletSection({
    super.key,
    required this.walletBalance,
    required this.orderAmount,
    required this.currency,
    required this.isWalletSelected,
    required this.onWalletToggle,
  });

  final double walletBalance;
  final double orderAmount;
  final String currency;
  final bool isWalletSelected;
  final ValueChanged<bool> onWalletToggle;

  @override
  Widget build(BuildContext context) {
    if (walletBalance <= 0) return const SizedBox.shrink();

    final canCoverFull = walletBalance >= orderAmount;
    final walletUsed = canCoverFull ? orderAmount : walletBalance;
    final displayBalance = isWalletSelected
        ? walletBalance - walletUsed
        : walletBalance;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
          decoration: AppDecorations.box(
            color: context.cs.surface,
            borderRadius: AppRadius.r14,
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceS,
            children: [
              Row(
                crossAxisAlignment: .start,
                children: [
                  _WalletCheckbox(
                    selected: isWalletSelected,
                    onChanged: onWalletToggle,
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: ThemeConstants.spaceXXS,
                      children: [
                        AppText(
                          '${AppConfig.appName} ${context.translate(LanguageLabelKeys.wallet)}',
                          style: context.tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            AppText(
                              context.translate(
                                LanguageLabelKeys.availableBalance,
                              ),
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                            AppText(
                              ' $currency${displayBalance.formatPrice(2)}',
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isWalletSelected)
                    Column(
                      crossAxisAlignment: .end,
                      children: [
                        AppText(
                          context.translate(LanguageLabelKeys.walletUsed),
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                        AppText(
                          '$currency${walletUsed.formatPrice(2)}',
                          style: context.tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSecondaryContainer,
                          ),
                        ),
                      ],
                    )
                  else
                    AppSvgIcon(
                      AssetsConstants.walletIcon,
                      size: ThemeConstants.iconXL,
                      color: context.cs.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletCheckbox extends StatelessWidget {
  const _WalletCheckbox({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 18,
        height: 18,
        decoration: AppDecorations.box(
          color: selected ? context.cs.primary : Colors.transparent,
          borderRadius: AppRadius.r4,
          border: Border.all(
            color: selected ? context.cs.primary : context.cs.onSurfaceVariant,
            width: 2,
          ),
        ),
        child: selected
            ? AppSvgIcon(
                AssetsConstants.checkIcon,
                size: ThemeConstants.iconXS,
                color: context.cs.onPrimary,
              )
            : null,
      ),
    );
  }
}
