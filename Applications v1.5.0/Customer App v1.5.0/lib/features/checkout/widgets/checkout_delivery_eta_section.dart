import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CheckoutDeliveryEtaSection extends StatelessWidget {
  const CheckoutDeliveryEtaSection({
    super.key,
    required this.distance,
    required this.itemCount,
    this.timeToDeliver,
    this.estimatedDeliveryDate,
    this.isPickup = false,
    this.pickupPreparationTime,
  });

  /// Raw distance string from API, e.g. "7.1 km".
  final String? distance;

  /// ETA string from API, e.g. "21 mins". Empty/null for ecommerce.
  final String? timeToDeliver;

  /// Estimated delivery date from API. Empty/null for quick commerce.
  final String? estimatedDeliveryDate;

  /// Number of items in the cart, shown in the subtitle.
  final int itemCount;

  /// Cart was priced in pickup mode — `time_to_deliver`/
  /// `estimated_delivery_date` are blank for pickup, so show the pickup
  /// store's prep time instead of falling back to a bare "Delivery" title.
  final bool isPickup;

  /// `cartData.pickup.preparation_time`, e.g. "15 mins".
  final String? pickupPreparationTime;

  @override
  Widget build(BuildContext context) {
    if (isPickup) {
      final prep = pickupPreparationTime ?? '';
      final title = prep.isNotEmpty
          ? '${context.translate(LanguageLabelKeys.readyForPickupIn)} $prep'
          : context.translate(LanguageLabelKeys.pickUp);
      return _buildRow(context, title);
    }
    final eta = timeToDeliver ?? '';
    final estimatedDate = estimatedDeliveryDate ?? '';
    final title = eta.isNotEmpty
        ? '${context.translate(LanguageLabelKeys.deliveryIn)} $eta'
        : estimatedDate.isNotEmpty
        ? '${context.translate(LanguageLabelKeys.estimatedDeliveryBy)} ${AppDateFormatter.formatDate(estimatedDate)}'
        : context.translate(LanguageLabelKeys.delivery);
    return _buildRow(context, title);
  }

  Widget _buildRow(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: ThemeConstants.paddingM,
      ),
      child: Row(
        spacing: ThemeConstants.spaceM,
        crossAxisAlignment: .start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: AppDecorations.box(
              color: context.cs.onSecondaryContainer.withValues(alpha: 0.12),
              shape: .circle,
            ),
            child: AppSvgIcon(
              AssetsConstants.orderTimeIcon,
              color: context.cs.onSecondaryContainer,
              size: ThemeConstants.iconL,
              fit: BoxFit.scaleDown,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AppText(
                  title,
                  style: context.tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppText(
                  '${context.translate(LanguageLabelKeys.shipmentOf)} $itemCount ${itemCount == 1 ? context.translate(LanguageLabelKeys.item) : context.translate(LanguageLabelKeys.items)}',
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
