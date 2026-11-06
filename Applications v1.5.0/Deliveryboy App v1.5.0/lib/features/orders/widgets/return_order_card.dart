import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/return_order_model.dart';
import '../../../commons/widgets/status_chip.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'order_card_shared.dart';

class ReturnOrderCard extends StatelessWidget {
  final ReturnRequestData order;
  final VoidCallback? onTap;

  const ReturnOrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final variantAttrs = order.returnItem?.variantAttributes;
    final variantText = (variantAttrs != null && variantAttrs.isNotEmpty)
        ? variantAttrs
              .map((v) => '${v.name ?? ''}: ${v.value ?? ''}')
              .join(', ')
        : null;
    final hasVariant = variantText != null;
    final addonText = formatOrderAddons(
      order.returnItem?.addons ?? const [],
      currency: order.currency ?? '',
    );
    final qty = order.quantity?.toString() ?? '1';
    final productLine = '$qty x ${order.productName ?? '—'}';
    final breakdown = PaymentBreakdown.compute(
      walletAmount: order.returnItem?.walletBalance,
      remainingAmount: order.finalTotal,
      paymentMethod: order.paymentMethod,
      isDelivered:
          order.returnStatusEnum == ReturnOrderStatus.receivedFromCustomer,
      refundAmount: order.returnItem?.refundAmount,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 10),
        decoration: AppDecorations.shadowedCard(
          color: Theme.of(context).cardColor,
          shadowColor: context.cs.shadow,
        ),
        child: Column(
          children: [
            // Section 1 — Return ID + status + date
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, ThemeConstants.paddingM),
              child: OrderCardHeader(
                orderNumber: '${order.returnNumber ?? order.id}',
                date: order.date,
                numberStyle: context.tt.titleSmall?.copyWith(
                  fontSize: 15,
                  color: context.cs.onSurface,
                ),
                dateStyle: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
                spacing: 4,
                statusChip: StatusChip.fromReturnOrderStatus(
                  context,
                  order.status,
                  orderStatusName: order.orderStatusName,
                ),
              ),
            ),

            Divider(height: 1, color: context.cs.outlineVariant),

            // Section 2 — Product name + variant + price
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, ThemeConstants.paddingM),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        AppText(
                          productLine,
                          style: context.tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                        if (hasVariant) ...[
                          AppSpacing.h3,
                          AppText(
                            variantText,
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (addonText.isNotEmpty) ...[
                          AppSpacing.h3,
                          AppText(
                            addonText,
                            style: context.tt.labelSmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: .ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.w8,
                  AppText(
                    '${order.currency ?? ''}${(order.discountedPrice ?? '0')}',
                    style: context.tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: context.cs.outlineVariant),

            // Section 3 — Payment chip + total
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      breakdown.combinedTotalLabel(context),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                  AppSpacing.w8,
                  AppText(
                    '${order.currency ?? ''}${breakdown.combinedTotalAmount.trimmedFixed()}',
                    style: context.tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (breakdown.mustCollectCash)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 10),
                child: CollectFromCustomerCallout(
                  breakdown: breakdown,
                  symbol: order.currency ?? '',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
