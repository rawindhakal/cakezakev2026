import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/product_image_placeholder.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/services/chat_conversation_resolver.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/widgets/order_tracking_delivery_partner_row.dart';
import 'package:customer/features/orders/widgets/order_tracking_shared_widgets.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/features/orders/utils/order_payment_utils.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OrderTrackingBottomSheet extends StatelessWidget {
  final OrderData order;
  final ScrollController scrollController;
  final VoidCallback onCallDeliveryBoy;

  const OrderTrackingBottomSheet({
    super.key,
    required this.order,
    required this.scrollController,
    required this.onCallDeliveryBoy,
  });

  bool get _hasDeliveryPartner => order.deliveryBoyName.hasValue;

  Future<void> _openSupportChat(BuildContext context) async {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    final conversationId = await resolveAdminConversationId();
    if (!context.mounted) return;
    AppNavigator.pushNamed(
      context,
      RouteNames.chat,
      arguments: ChatScreenArgs(
        chatType: ChatType.adminChat,
        recipientName: context.translate(LanguageLabelKeys.chatWithSupport),
        recipientId: AuthHiveBox.instance.userId,
        conversationId: conversationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textPrimary = context.cs.onSurface;
    final textSecondary = context.cs.onSurfaceVariant;
    final orderIdText = order.id?.toString() ?? '';
    final customerName = order.userName.hasValue
        ? order.userName!
        : (order.address?.name.hasValue ?? false ? order.address!.name! : '');
    final mobileNumber = order.address?.mobile.hasValue ?? false
        ? order.address!.mobile!
        : (order.mobile.hasValue ? order.mobile! : '');
    final orderPlacedDate = order.date.hasValue
        ? AppDateFormatter.formatDateTime(order.date!)
        : '';

    return Container(
      decoration: AppDecorations.bottomSheet(
        color: context.cs.surfaceContainer,
        borderRadius: AppRadius.top20,
        boxShadow: [
          BoxShadow(
            color: context.cs.scrim.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsetsDirectional.zero,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsetsDirectional.only(
                top: ThemeConstants.paddingS,
                bottom: ThemeConstants.paddingXS,
              ),
              width: 40,
              height: 4,
              decoration: AppDecorations.dragHandle(
                color: context.cs.outlineVariant,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingS,
              ThemeConstants.paddingL,
              ThemeConstants.paddingXXL + context.bottomSafePadding,
            ),
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceM,
              children: [
                if (_hasDeliveryPartner)
                  _SheetCard(
                    child: OrderTrackingDeliveryPartnerRow(
                      order: order,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onCallDeliveryBoy: onCallDeliveryBoy,
                    ),
                  )
                else if (order.otp != null && order.otp != 0)
                  AppSpacing.shrink,
                _SheetCard(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      _SectionHeader(
                        icon: AppSvgIcon(
                          AssetsConstants.deliveryBikeIcon,
                          size: ThemeConstants.iconM,
                          color: textPrimary,
                        ),
                        title: context.translate(
                          LanguageLabelKeys.yourDeliveryDetails,
                        ),
                        subtitle: context.translate(
                          LanguageLabelKeys.detailsOfCurrentOrder,
                        ),
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      AppSpacing.h14,
                      Divider(height: 1, color: context.cs.outlineVariant),
                      AppSpacing.h14,
                      TrackingInfoRow(
                        label: context.translate(
                          LanguageLabelKeys.deliveryAddress,
                        ),
                        value: order.address?.address ?? '',
                        textColor: textPrimary,
                        subColor: textSecondary,
                        isDark: isDark,
                      ),
                      if (customerName.isNotEmpty) ...[
                        AppSpacing.h12,
                        TrackingInfoRow(
                          label: context.translate(LanguageLabelKeys.name),
                          value: customerName,
                          textColor: textPrimary,
                          subColor: textSecondary,
                          isDark: isDark,
                        ),
                      ],
                      if (mobileNumber.isNotEmpty) ...[
                        AppSpacing.h12,
                        TrackingInfoRow(
                          label: context.translate(
                            LanguageLabelKeys.mobileNumber,
                          ),
                          value: mobileNumber,
                          textColor: textPrimary,
                          subColor: textSecondary,
                          isDark: isDark,
                        ),
                      ],
                      if (order.paymentMethod.hasValue) ...[
                        AppSpacing.h12,
                        TrackingInfoRow(
                          label: context.translate(
                            LanguageLabelKeys.paymentMethod,
                          ),
                          value: formatOrderPaymentMethod(
                            context,
                            order.paymentMethod!,
                          ),
                          textColor: textPrimary,
                          subColor: textSecondary,
                          isDark: isDark,
                        ),
                      ],
                      if (orderPlacedDate.isNotEmpty) ...[
                        AppSpacing.h12,
                        TrackingInfoRow(
                          label: context.translate(
                            LanguageLabelKeys.orderPlaced,
                          ),
                          value: orderPlacedDate,
                          textColor: textPrimary,
                          subColor: textSecondary,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
                _SheetCard(
                  child: InkWell(
                    onTap: () => _openSupportChat(context),
                    borderRadius: AppRadius.r14,
                    child: Row(
                      children: [
                        Expanded(
                          child: _SectionHeader(
                            icon: AppSvgIcon(
                              AssetsConstants.supportChatIcon,
                              size: ThemeConstants.iconM,
                              color: textPrimary,
                            ),
                            title: context.translate(
                              LanguageLabelKeys.needHelp,
                            ),
                            subtitle: context.translate(
                              LanguageLabelKeys.needHelpSubtitle,
                            ),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        Transform.flip(
                          flipX:
                              Directionality.of(context) == TextDirection.rtl,
                          child: AppSvgIcon(
                            AssetsConstants.arrowRightIcon,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SheetCard(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: .start,
                              spacing: ThemeConstants.spaceXXS,
                              children: [
                                AppText(
                                  context.translate(
                                    LanguageLabelKeys.orderSummary,
                                  ),
                                  style: context.tt.bodyMedium?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                AppText(
                                  '${context.translate(LanguageLabelKeys.orderId)} - ${AppConstants.hashSymbol}$orderIdText',
                                  style: context.tt.bodySmall?.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (orderIdText.isNotEmpty)
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: orderIdText),
                                );
                                AppSnackBar.show(
                                  context: context,
                                  message: context.translate(
                                    LanguageLabelKeys.copied,
                                  ),
                                  type: SnackBarType.success,
                                );
                              },
                              child: AppSvgIcon(
                                AssetsConstants.copyIcon,
                                size: ThemeConstants.iconXS,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                      if ((order.items ?? []).isNotEmpty) ...[
                        AppSpacing.h12,
                        Divider(height: 1, color: context.cs.outlineVariant),
                        AppSpacing.h12,
                        ...order.items!
                            .take(2)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  bottom: ThemeConstants.paddingS,
                                ),
                                child: _SummaryItemRow(item: item),
                              ),
                            ),
                      ],
                      Center(
                        child: TextButton(
                          onPressed: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.orderDetail,
                            arguments: OrderDetailArgs(
                              orderId: orderIdText,
                              isOngoing: true,
                            ),
                          ),
                          child: AppText(
                            context.translate(
                              LanguageLabelKeys.viewOrderSummary,
                            ),
                            style: context.tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.cs.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
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

/// Icon-avatar + title/subtitle header used at the top of a [_SheetCard].
class _SectionHeader extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: ThemeConstants.spaceM,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: AppDecorations.box(
            color: context.cs.surfaceContainerHighest,
            shape: .circle,
          ),
          child: Center(child: icon),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AppText(
                title,
                style: context.tt.bodyMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              AppText(
                subtitle,
                style: context.tt.bodySmall?.copyWith(color: textSecondary),
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryItemRow extends StatelessWidget {
  final OrderItems item;

  const _SummaryItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.hasValue;
    final variant =
        VariantAttributesFormatter.format(item.variantAttributes) ?? '';

    final thumbSize = context.screenWidth * 0.12;

    return Row(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        hasImage
            ? AppNetworkImage(
                url: item.imageUrl!,
                width: thumbSize,
                height: thumbSize,
                borderRadius: AppRadius.r8,
              )
            : ProductImagePlaceholder(
                size: thumbSize,
                borderRadius: AppRadius.r8,
              ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text.rich(
                ProductTypeIcon.nameSpan(
                  productType: item.productType,
                  name: item.productName ?? '',
                  size: ThemeConstants.iconXXS,
                ),
                style: context.tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
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
                ),
              AppText(
                'x${item.quantity ?? 1}',
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Flat, tinted section card — groups related tracking info the way
/// Blinkit/Zomato separate their order-tracking sheet into distinct blocks
/// instead of a single list divided by hairlines.
class _SheetCard extends StatelessWidget {
  final Widget child;

  const _SheetCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r14,
        border: Border.all(color: context.cs.outlineVariant, width: 0.5),
      ),
      child: child,
    );
  }
}
