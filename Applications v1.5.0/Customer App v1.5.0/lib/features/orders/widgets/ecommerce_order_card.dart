import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/product_image_placeholder.dart';
import 'package:customer/core/constants/theme_constants.dart';

class EcommerceOrderCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  final VoidCallback onTap;
  final VoidCallback? onReorder;

  const EcommerceOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onReorder,
  });

  bool get _isActive => order.activeStatus == OrderStatus.paymentPending;
  bool get _hasTimeline => order.timeline?.isNotEmpty ?? false;
  bool get _isDelivered => order.activeStatus == OrderStatus.delivered;
  bool get _isRated =>
      order.productRating == true && (order.itemRating?.isNotEmpty ?? false);
  bool get _showRate =>
      order.productRating == true &&
      _isDelivered &&
      !(order.isCancellable ?? false) &&
      !(order.isReturnable ?? false) &&
      !((order.returnRequested ?? 0) != 0) &&
      !_isRated;
  bool get _hasRatingBanner => _showRate || _isRated;

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatusLabels.color(context, order.activeStatus);
    final statusIcon = OrderStatusLabels.icon(order.activeStatus);
    final dividerColor = context.cs.outlineVariant;
    final hasDate = order.date.hasValue;
    final variant =
        VariantAttributesFormatter.format(order.variantAttributes) ?? '';
    final hasImage = order.image.hasValue;
    final orderCreatedAt = AppDateFormatter.parse(order.date);
    final returnDeadline = (orderCreatedAt != null && order.returnDays != null)
        ? orderCreatedAt.add(Duration(days: order.returnDays!))
        : null;
    final hasReturnWindow =
        (order.isReturnable ?? false) &&
        order.returnDays != null &&
        returnDeadline != null &&
        DateTime.now().isBefore(returnDeadline);
    final hasRatingBanner = _hasRatingBanner;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: .center,
            spacing: ThemeConstants.spaceM,
            children: [
              _StatusIcon(color: statusColor, icon: statusIcon),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXXS,
                  children: [
                    AppText(
                      order.orderItemStatus ??
                          (_isActive
                              ? context.translate(LanguageLabelKeys.ongoing)
                              : context.translate(LanguageLabelKeys.completed)),
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: statusColor,
                      ),
                    ),
                    if (hasDate) ...[
                      AppText(
                        AppDateFormatter.formatDateTime(order.date!),
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.r12,
            child: Container(
              padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
              decoration: AppDecorations.box(
                border: hasRatingBanner
                    ? Border(
                        top: BorderSide(color: dividerColor),
                        left: BorderSide(color: dividerColor),
                        right: BorderSide(color: dividerColor),
                      )
                    : Border.all(color: dividerColor),
                borderRadius: hasRatingBanner
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : AppRadius.r12,
              ),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      hasImage
                          ? AppNetworkImage(
                              url: order.image!,
                              width: context.screenWidth * 0.15,
                              height: context.screenWidth * 0.15,
                              borderRadius: AppRadius.r8,
                            )
                          : ProductImagePlaceholder(
                              size: context.screenWidth * 0.15,
                              borderRadius: AppRadius.r8,
                            ),
                      AppSpacing.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          spacing: ThemeConstants.spaceXXS,
                          children: [
                            Text.rich(
                              ProductTypeIcon.nameSpan(
                                productType: order.productType,
                                name: order.productName ?? '',
                                size: ThemeConstants.iconXS,
                              ),
                              style: context.tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                            if (variant.isNotEmpty) ...[
                              AppText(
                                variant,
                                style: context.tt.bodySmall?.copyWith(
                                  color: context.cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: .ellipsis,
                              ),
                            ],
                            // Add-on module: chosen options in one
                            // receipt-style line ("Cheese burst +₹30,
                            // 2 × Olives").
                            if (order.addons?.isNotEmpty ?? false)
                              AppText(
                                formatCartAddons(
                                  order.addons!,
                                  currency: order.currency ?? '',
                                  decimalPoint: order.decimalPoint ?? 2,
                                ),
                                style: context.tt.bodySmall?.copyWith(
                                  color: context.cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: .ellipsis,
                              ),
                            AppText(
                              '${order.currency ?? ''}${order.discountedPrice ?? order.price ?? 0}',
                              style: context.tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.flip(
                        flipX: Directionality.of(context) == TextDirection.rtl,
                        child: AppSvgIcon(
                          AssetsConstants.arrowRightIcon,
                          color: context.cs.onSurfaceVariant,
                          bakeTint: true,
                          size: ThemeConstants.iconL,
                        ),
                      ),
                    ],
                  ),
                  if (hasReturnWindow) ...[
                    AppSpacing.h8,
                    Row(
                      spacing: ThemeConstants.spaceS,
                      children: [
                        AppSvgIcon(
                          AssetsConstants.closeCircleIcon,
                          size: ThemeConstants.iconXS,
                          color: context.cs.onSurfaceVariant,
                          bakeTint: true,
                        ),
                        Expanded(
                          child: AppText(
                            '${context.translate(LanguageLabelKeys.returnWithin)} '
                            '${order.returnDays} '
                            '${context.translate(LanguageLabelKeys.days)}',
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isDelivered && (_showRate || _isRated)) ...[
            EcommerceItemRatingControl(order: order),
          ],

          if (onReorder != null || (_isActive && _hasTimeline)) ...[
            AppSpacing.h10,
            Row(
              mainAxisAlignment: .end,
              spacing: ThemeConstants.spaceM,
              children: [
                if (_isActive && _hasTimeline)
                  AppButton(
                    label: context.translate(LanguageLabelKeys.track),
                    onPressed: () =>
                        showOrderTimelineSheet(context, order.timeline!),
                    variant: AppButtonVariant.outline,
                    fullWidth: false,
                    height: 32,
                    fontSize: 13,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingL,
                      vertical: ThemeConstants.paddingXS,
                    ),
                    prefixIcon: AppSvgIcon(
                      AssetsConstants.addressIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.primary,
                      bakeTint: true,
                    ),
                  ),
                if (onReorder != null)
                  AppButton(
                    label: context.translate(LanguageLabelKeys.reorder),
                    onPressed: onReorder,
                    fullWidth: false,
                    height: 32,
                    fontSize: 13,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingL,
                      vertical: ThemeConstants.paddingXS,
                    ),
                    prefixIcon: AppSvgIcon(
                      AssetsConstants.refreshIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.onPrimary,
                      bakeTint: true,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final Color color;
  final String icon;
  const _StatusIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: AppDecorations.box(
                color: color.withValues(alpha: 0.12),
                shape: .circle,
              ),
              alignment: Alignment.center,
              child: AppSvgIcon(
                AssetsConstants.orderIcon,
                size: ThemeConstants.iconL,
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 5,
            end: 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: AppDecorations.box(
                color: color,
                shape: .circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXS,
              ),
              child: AppSvgIcon(
                icon,
                size: ThemeConstants.iconXXS,
                color: context.cs.onPrimary,
                bakeTint: true,
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
