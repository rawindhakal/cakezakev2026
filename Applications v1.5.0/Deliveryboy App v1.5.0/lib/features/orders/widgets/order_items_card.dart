import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/widgets/product_item_row.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/order_detail_model.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class OrderItemsCard extends StatelessWidget {
  final List<OrderItems> items;
  final String symbol;
  const OrderItemsCard({super.key, required this.items, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, ThemeConstants.paddingM),
            child: AppText(
              context.translate(LanguageLabelKeys.items),
              style: context.tt.titleSmall?.copyWith(
                color: context.cs.onSurface,
              ),
            ),
          ),
          Divider(height: 1, color: context.cs.outlineVariant),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _ItemRow(item: item, symbol: symbol),
                if (idx < items.length - 1)
                  Divider(height: 1, color: context.cs.outlineVariant),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItems item;
  final String symbol;
  const _ItemRow({required this.item, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, ThemeConstants.paddingM),
      child: ProductItemRow(
        image: item.image,
        quantity: item.quantity,
        productName: item.productName,
        productType: item.productType,
        variantLabel: formatVariantValues(item.variantAttributes),
        symbol: symbol,
        price: item.price,
        discountedPrice: item.discountedPrice,
        addons: item.addons ?? const [],
        addonTotal: item.addonTotal ?? 0,
      ),
    );
  }
}
