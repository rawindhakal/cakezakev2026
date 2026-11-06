import 'package:deliveryboy/commons/widgets/app_item_image.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/product_type_icon.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_addon_list.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Single product row shared by order-detail item cards (quick, ecommerce,
/// return) — image, qty x name, variant, price (with strikethrough MRP).
/// Keeps the item listing UI consistent across all three order types.
class ProductItemRow extends StatelessWidget {
  final String? image;
  final num? quantity;
  final String? productName;

  /// Veg / non-veg / … mark shown inline before the name; 0 = none.
  final int? productType;
  final String variantLabel;
  final String symbol;
  final num? price;
  final num? discountedPrice;

  /// Add-on module: order snapshot of the chosen options; empty when none.
  final List<OrderAddon> addons;
  final double addonTotal;

  const ProductItemRow({
    super.key,
    required this.image,
    required this.quantity,
    required this.productName,
    this.productType,
    required this.variantLabel,
    required this.symbol,
    required this.price,
    required this.discountedPrice,
    this.addons = const [],
    this.addonTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    final imgSize = context.screenWidth * 0.18;
    final hasDiscount =
        discountedPrice != null && discountedPrice != 0 && discountedPrice != price;
    final effectivePrice = hasDiscount ? discountedPrice! : (price ?? 0);

    return Row(
      crossAxisAlignment: .start,
      children: [
        AppItemImage(url: image, size: imgSize),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text.rich(
                ProductTypeIcon.nameSpan(
                  productType: productType,
                  name:
                      '${quantity ?? 1} ${AppConstants.crossQtySymbol} ${productName ?? '—'}',
                  size: ThemeConstants.iconXS,
                ),
                style: context.tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
                maxLines: 2,
                overflow: .ellipsis,
              ),
              if (variantLabel.isNotEmpty) ...[
                AppSpacing.h4,
                AppText(
                  variantLabel,
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (addons.isNotEmpty) ...[
                AppSpacing.h4,
                OrderAddonList(
                  addons: addons,
                  addonTotal: addonTotal,
                  currency: symbol,
                ),
              ],
              AppSpacing.h8,
              Row(
                children: [
                  AppText(
                    '$symbol${effectivePrice.trimmedFixed()}',
                    style: context.tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.cs.onSurface,
                    ),
                  ),
                  if (hasDiscount) ...[
                    AppSpacing.w8,
                    AppText(
                      '$symbol${(price ?? 0).trimmedFixed()}',
                      style: context.tt.labelSmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
