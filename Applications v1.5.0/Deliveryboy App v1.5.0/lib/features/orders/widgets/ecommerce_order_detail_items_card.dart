import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/orders/widgets/product_item_row.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import '../models/ecommerce_order_model.dart';
import '../../../core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class EcommerceOrderDetailItemsCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  final String symbol;
  const EcommerceOrderDetailItemsCard({
    super.key,
    required this.order,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final otherItems = order.otherItems ?? [];

    return Column(
      crossAxisAlignment: .start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
          decoration: AppDecorations.shadowedCard(
            color: Theme.of(context).cardColor,
            shadowColor: context.cs.shadow,
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.items),
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
              AppSpacing.h10,
              Divider(height: 1, color: context.cs.outlineVariant),
              AppSpacing.h12,
              _MainItemRow(order: order, symbol: symbol),
            ],
          ),
        ),
        if (otherItems.isNotEmpty) ...[
          AppSpacing.h12,
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
            decoration: AppDecorations.shadowedCard(
              color: Theme.of(context).cardColor,
              shadowColor: context.cs.shadow,
            ),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AppText(
                  '${context.translate(LanguageLabelKeys.otherItemsInOrder)} (${otherItems.length})',
                  style: context.tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                AppSpacing.h10,
                Divider(height: 1, color: context.cs.outlineVariant),
                AppSpacing.h12,
                ...otherItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 12),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: item.orderItemId == null
                          ? null
                          : () => AppNavigator.pushNamed(
                              context,
                              RouteNames.ecommerceOrderDetail,
                              arguments: item.orderItemId.toString(),
                            ),
                      child: _OtherItemRow(item: item, symbol: symbol),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MainItemRow extends StatelessWidget {
  final EcommerceOrderDataModel order;
  final String symbol;
  const _MainItemRow({required this.order, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return ProductItemRow(
      image: order.image,
      quantity: order.quantity,
      productName: order.productName ?? order.name,
      productType: order.productType,
      variantLabel: formatVariantPairs(order.variantAttributes) ?? '',
      symbol: symbol,
      price: order.price,
      discountedPrice: order.discountedPrice,
      addons: order.addons ?? const [],
      addonTotal: order.addonTotal ?? 0,
    );
  }
}

class _OtherItemRow extends StatelessWidget {
  final OtherItems item;
  final String symbol;
  const _OtherItemRow({required this.item, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return ProductItemRow(
      image: item.image,
      quantity: item.quantity,
      productName: item.productName,
      productType: item.productType,
      variantLabel: item.statusName ?? '',
      symbol: symbol,
      price: item.finalTotal,
      discountedPrice: null,
    );
  }
}
