import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import '../models/ecommerce_order_model.dart';
import '../models/order_status.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/status_chip.dart';
import 'order_card_shared.dart';

class EcommerceOrderCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  final VoidCallback? onTap;

  const EcommerceOrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final symbol = order.currency ?? "";
    final dividerColor = context.cs.outlineVariant;
    final otherItemsCount = order.otherItems?.length ?? 0;
    final breakdown = PaymentBreakdown.compute(
      walletAmount: order.walletBalance,
      remainingAmount: order.finalTotal,
      paymentMethod: order.paymentMethod,
      isDelivered: order.activeStatus == OrderStatus.delivered.id,
      refundAmount: order.refundAmount,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
        decoration: AppDecorations.shadowedCard(
          color: Theme.of(context).cardColor,
          shadowColor: context.cs.shadow,
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            OrderCardHeader(
              orderNumber: '${order.orderNumber ?? order.id}',
              date: order.date,
              statusChip: StatusChip.fromDynamicStatus(
                context,
                order.activeStatus?.toString(),
                orderStatusName: order.orderItemStatus,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              child: Divider(height: 1, color: dividerColor),
            ),
            CompactProductRow(
              image: order.image,
              name: '${order.quantity ?? 1} x ${order.productName ?? order.name ?? '—'}',
              productType: order.productType,
              variant: formatVariantPairs(order.variantAttributes) ?? '',
              addons: formatOrderAddons(
                order.addons ?? const [],
                currency: symbol,
              ),
              currency: symbol,
              price: order.discountedPrice ?? 0,
            ),
            if (otherItemsCount > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: ThemeConstants.paddingXS),
                child: AppText(
                  '+$otherItemsCount ${context.translate(LanguageLabelKeys.moreItems)}',
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              child: Divider(height: 1, color: dividerColor),
            ),
            OrderCardFooter(breakdown: breakdown, symbol: symbol),
          ],
        ),
      ),
    );
  }
}
