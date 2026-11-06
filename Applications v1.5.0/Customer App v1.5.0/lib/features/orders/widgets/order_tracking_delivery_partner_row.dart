import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';

/// Rider intro card — "I'm {name}, your delivery partner" + call button.
class OrderTrackingDeliveryPartnerRow extends StatelessWidget {
  final OrderData order;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onCallDeliveryBoy;

  const OrderTrackingDeliveryPartnerRow({
    super.key,
    required this.order,
    required this.textPrimary,
    required this.textSecondary,
    required this.onCallDeliveryBoy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        Row(
          crossAxisAlignment: .start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: AppDecorations.box(
                color: context.cs.primary.withValues(alpha: 0.1),
                shape: .circle,
              ),
              child: AppSvgIcon(
                AssetsConstants.userIcon,
                color: context.cs.primary,
                size: ThemeConstants.iconL,
                fit: BoxFit.scaleDown,
              ),
            ),
            AppSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceXXS,
                children: [
                  AppText(
                    "${context.translate(LanguageLabelKeys.iAm)} "
                    "${order.deliveryBoyName!}, "
                    "${context.translate(LanguageLabelKeys.yourDeliveryPartner)}",
                    style: context.tt.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  AppText(
                    context.translate(
                      LanguageLabelKeys.reachingLocationSoonMessage,
                    ),
                    style: context.tt.bodySmall?.copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
            if (order.deliveryBoyMobile.hasValue)
              GestureDetector(
                onTap: onCallDeliveryBoy,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: AppDecorations.box(
                    color: context.cs.primary,
                    shape: .circle,
                    border: Border.all(
                      color: context.cs.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: AppSvgIcon(
                    AssetsConstants.phoneIcon,
                    color: context.cs.onPrimary,
                    size: ThemeConstants.iconS,
                    fit: BoxFit.scaleDown,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
