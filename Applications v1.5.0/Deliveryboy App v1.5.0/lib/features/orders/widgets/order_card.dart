import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/status_chip.dart';
import 'order_card_shared.dart';

class OrderCard extends StatelessWidget {
  final OrderData order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final symbol = order.currency ?? "";
    final dividerColor = context.cs.outlineVariant;
    final items = order.items ?? [];
    final displayItems = items.take(2).toList();
    final extraCount = items.length - displayItems.length;
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
              date: order.date!,
              statusChip: StatusChip.fromDynamicStatus(
                context,
                order.activeStatus?.toString(),
                orderStatusName: order.orderStatusName,
              ),
            ),

            if ((order.deliveryDate ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  '🗓 Deliver: ${order.deliveryDate!.substring(0, 10)}${(order.deliverySlot ?? '').isNotEmpty ? ' · ${order.deliverySlot}' : ''}',
                  style: context.tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.primary,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              child: Divider(height: 1, color: dividerColor),
            ),

            // ── Items ──
            if (displayItems.isNotEmpty) ...[
              AppSpacing.h10,
              ...displayItems.map(
                (item) => CompactProductRow(
                  name: '${item.quantity ?? 0} x ${item.productName ?? ''}',
                  productType: item.productType,
                  variant: formatVariantPairs(item.variantAttributes) ?? '',
                  addons: formatOrderAddons(
                    item.addons ?? const [],
                    currency: symbol,
                  ),
                  currency: symbol,
                  price: item.discountedPrice ?? 0,
                  padding: const EdgeInsetsDirectional.only(bottom: 6),
                ),
              ),
              if (extraCount > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: ThemeConstants.paddingXS),
                  child: AppText(
                    '+$extraCount more item${extraCount > 1 ? 's' : ''}',
                    style: context.tt.bodySmall?.copyWith(
                      color: context.cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],

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
