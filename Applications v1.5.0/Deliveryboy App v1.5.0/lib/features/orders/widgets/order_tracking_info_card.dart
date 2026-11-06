import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/widgets/order_action_buttons.dart'
    show launchCall;
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Compact contact bar for the live-tracking bottom sheet — deliberately
/// lighter than [PickupDeliveryCard] (no bordered sub-card / icon badges):
/// this sheet floats directly over the map, so it reads better as one flat
/// surface than as a card nested inside a card.
class OrderTrackingInfoCard extends StatelessWidget {
  final String customerName;
  final String customerNumber;
  final String? customerAlternateNumber;
  final String address;
  final VoidCallback? onChatCustomer;

  const OrderTrackingInfoCard({
    super.key,
    required this.customerName,
    required this.customerNumber,
    this.customerAlternateNumber,
    required this.address,
    this.onChatCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(
        color: context.cs.surface,
        borderRadius: AppRadius.bottomSheetRadius,
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        10,
        ThemeConstants.paddingL,
        context.bottomSafePadding + 16,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Center(
            child: Container(
              width: context.screenWidth * 0.096,
              height: context.screenHeight * 0.005,
              decoration: AppDecorations.card(
                color: context.cs.outlineVariant,
                borderRadius: AppRadius.r2,
              ),
            ),
          ),
          AppSpacing.h14,
          AppText(
            context.translate(LanguageLabelKeys.deliveryInfo),
            style: context.tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.h10,
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.cs.primaryContainer,
                child: AppSvgIcon(
                  AssetsConstants.userIcon,
                  size: ThemeConstants.iconM,
                  color: context.cs.primary,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    AppText(
                      customerName,
                      style: context.tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                    AppText(
                      address,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: .ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              _RoundIconButton(
                icon: AssetsConstants.phoneIcon,
                onTap: () => launchCall(customerNumber),
              ),
              if (onChatCustomer != null) ...[
                AppSpacing.w8,
                _RoundIconButton(
                  icon: AssetsConstants.supportChatIcon,
                  onTap: onChatCustomer!,
                ),
              ],
            ],
          ),
          if (customerAlternateNumber.isNotNullOrEmpty) ...[
            AppSpacing.h10,
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 10,
                vertical: ThemeConstants.paddingS,
              ),
              decoration: AppDecorations.card(
                color: context.cs.surfaceContainerLow,
                borderRadius: AppRadius.r10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        AppText(
                          context.translate(LanguageLabelKeys.alternateMobile),
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                        AppText(
                          customerAlternateNumber!,
                          style: context.tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    icon: AssetsConstants.phoneIcon,
                    size: ThemeConstants.iconXL,
                    iconSize: ThemeConstants.iconXS,
                    onTap: () => launchCall(customerAlternateNumber),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: AppSvgIcon(icon, size: iconSize, color: context.cs.primary),
          ),
        ),
      ),
    );
  }
}
