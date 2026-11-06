import 'package:deliveryboy/commons/widgets/app_item_image.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/product_type_icon.dart';
import 'package:deliveryboy/commons/widgets/status_chip.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Header row shared by [OrderCard], [EcommerceOrderCard] and
/// [ReturnOrderCard]: order/return number + date on the left, status chip
/// on the right. The status chip is passed in since order and return
/// statuses use different [StatusChip] factories; number/date styling can
/// be overridden so each card keeps its existing look.
class OrderCardHeader extends StatelessWidget {
  final String orderNumber;
  final dynamic date;
  final Widget statusChip;
  final TextStyle? numberStyle;
  final TextStyle? dateStyle;
  final double spacing;

  const OrderCardHeader({
    super.key,
    required this.orderNumber,
    required this.date,
    required this.statusChip,
    this.numberStyle,
    this.dateStyle,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AppText(orderNumber, style: numberStyle ?? context.tt.displayMedium),
              SizedBox(height: spacing),
              AppText(
                AppDateFormatter.formatDateTime(date),
                style:
                    dateStyle ??
                    context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
        AppSpacing.w8,
        statusChip,
      ],
    );
  }
}

/// Payment-label + combined-total footer row shared by [OrderCard] and
/// [EcommerceOrderCard], plus the optional "collect from customer" callout.
class OrderCardFooter extends StatelessWidget {
  final PaymentBreakdown breakdown;
  final String symbol;

  const OrderCardFooter({
    super.key,
    required this.breakdown,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          mainAxisAlignment: .spaceBetween,
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
              '$symbol${breakdown.combinedTotalAmount.trimmedFixed()}',
              style: context.tt.displayMedium?.copyWith(
                color: context.cs.onSurface,
              ),
            ),
          ],
        ),
        if (breakdown.mustCollectCash) ...[
          AppSpacing.h10,
          CollectFromCustomerCallout(breakdown: breakdown, symbol: symbol),
        ],
      ],
    );
  }
}

/// Compact "qty x name" row with optional variant, trailing price, and an
/// optional leading thumbnail — shared by [OrderCard] and
/// [EcommerceOrderCard] list rows so both stay in sync instead of each
/// carrying its own near-identical private row widget.
class CompactProductRow extends StatelessWidget {
  final String? image;
  final String name;

  /// Veg / non-veg / … mark shown inline before the name; 0 = none.
  final int? productType;
  final String variant;

  /// Add-on module: chosen options as one receipt-style line
  /// ("Cheese burst +₹30, Paneer, 2 × Olives"); empty when none.
  final String addons;
  final String? currency;
  final num price;
  final EdgeInsetsDirectional padding;

  const CompactProductRow({
    super.key,
    this.image,
    required this.name,
    this.productType,
    required this.variant,
    this.addons = '',
    required this.currency,
    required this.price,
    this.padding = EdgeInsetsDirectional.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: .start,
        children: [
          if (image != null) ...[
            AppItemImage(
              url: image,
              size: context.screenWidth * 0.13,
              borderRadius: AppRadius.r8,
              iconSize: context.screenWidth * 0.053,
            ),
            AppSpacing.w10,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text.rich(
                  ProductTypeIcon.nameSpan(
                    productType: productType,
                    name: name,
                    size: ThemeConstants.iconXS,
                  ),
                  style: context.tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                if (variant.isNotEmpty)
                  AppText(
                    variant,
                    style: context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                if (addons.isNotEmpty)
                  AppText(
                    addons,
                    style: context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
              ],
            ),
          ),
          AppSpacing.w8,
          AppText(
            '$currency${price.trimmedFixed()}',
            style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
