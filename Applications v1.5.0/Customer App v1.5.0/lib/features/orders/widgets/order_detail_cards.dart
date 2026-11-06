import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/features/products/widgets/cart_addon_list.dart';
import 'package:customer/commons/widgets/app_confirm_dialog.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/product_image_placeholder.dart';
import 'package:customer/commons/widgets/tax_breakdown_sheet.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/services/chat_conversation_resolver.dart';
import 'package:customer/features/orders/cubit/order_detail_cubit.dart';
import 'package:customer/features/orders/cubit/order_status_update_cubit.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/utils/order_payment_utils.dart';
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/features/orders/widgets/rate_product_sheet.dart';
import 'package:customer/features/products/cubit/rating_add_update_cubit.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Confirm + optional reason prompt shared by cancel/return — returns the
/// entered reason (possibly empty) if confirmed, or null if dismissed.
Future<String?> _promptReason(
  BuildContext context,
  String title,
  String message,
) async {
  final controller = TextEditingController();
  final confirmed = await AppConfirmDialog.show(
    context: context,
    icon: AppConfirmDialogIcon.warning,
    title: title,
    message: message,
    cancelLabel: context.translate(LanguageLabelKeys.cancel),
    confirmLabel: context.translate(LanguageLabelKeys.submit),
    extraContent: AppTextField(
      controller: controller,
      maxLines: 2,
      hintText: context.translate(LanguageLabelKeys.enterMessage),
    ),
  );
  return confirmed == true ? controller.text.trim() : null;
}

/// Bottom sheet asking for an optional cancel reason — returns the entered
/// reason (possibly empty) if confirmed, or null if dismissed.
Future<String?> showCancelOrderSheet(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? hint,
}) {
  return showAppBottomSheet<String?>(
    context,
    showDragHandle: false,
    padding: null,
    builder: (_) => _CancelOrderSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      hint: hint,
    ),
  );
}

class _CancelOrderSheet extends StatefulWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? hint;
  const _CancelOrderSheet({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.hint,
  });

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingXL +
            context.keyboardInset +
            context.bottomSafePadding,
      ),
      child: SlideAnimationList(
        crossAxisAlignment: .start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: AppDecorations.dragHandle(
                color: context.cs.outlineVariant,
              ),
            ),
          ),
          AppSpacing.h20,
          Center(
            child: AppText(
              widget.title,
              textAlign: .center,
              style: context.tt.titleLarge?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.cs.onSurface,
              ),
            ),
          ),
          AppSpacing.h6,
          Center(
            child: AppText(
              widget.message,
              textAlign: .center,
              style: context.tt.bodySmall?.copyWith(
                fontSize: 13,
                color: context.cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          AppSpacing.h20,
          AppTextField(
            controller: _controller,
            maxLines: 3,
            hintText:
                widget.hint ??
                context.translate(LanguageLabelKeys.enterMessage),
          ),
          AppSpacing.h24,
          Row(
            spacing: ThemeConstants.spaceM,
            children: [
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.cancel),
                  variant: AppButtonVariant.outline,
                  height: 48,
                  onPressed: () => AppNavigator.pop(context, null),
                ),
              ),
              Expanded(
                child: AppButton(
                  label:
                      widget.confirmLabel ??
                      context.translate(LanguageLabelKeys.cancelOrder),
                  height: 48,
                  onPressed: () =>
                      AppNavigator.pop(context, _controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _runStatusUpdate(
  BuildContext context, {
  required String orderId,
  required String status,
  String? orderItemId,
  required String from,
  required String reason,
}) {
  context.read<OrderStatusUpdateCubit>().updateStatus(
    orderId: orderId,
    status: status,
    orderItemId: orderItemId,
    from: from,
    reason: reason,
  );
}

class OrderDetailInstructionCard extends StatelessWidget {
  final String note;
  const OrderDetailInstructionCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return OrderDetailCard(
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: AppDecorations.box(
              color: context.cs.errorContainer.withValues(alpha: 0.12),
              shape: .circle,
            ),
            child: AppSvgIcon(
              AssetsConstants.noteIcon,
              size: ThemeConstants.iconS,
              color: context.cs.errorContainer,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXS,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.deliveryInstruction),
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                AppText(
                  note,
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: context.cs.onSurfaceVariant,
                    height: 1.4,
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

class OrderDetailOtpCard extends StatelessWidget {
  final String otp;
  const OrderDetailOtpCard({super.key, required this.otp});

  void _copyOtp(BuildContext context) {
    Clipboard.setData(ClipboardData(text: otp));
    AppSnackBar.show(
      context: context,
      message: context.translate(LanguageLabelKeys.copied),
      type: SnackBarType.success,
    );
  }

  void _shareOtp(BuildContext context) {
    SharePlus.instance.share(
      ShareParams(
        text: '${context.translate(LanguageLabelKeys.deliveryOtp)}: $otp',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = context.cs.outlineVariant;
    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.deliveryVerification),
            style: context.tt.bodyMedium?.copyWith(
              color: context.cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          AppSpacing.h8,
          AppText(
            context.translate(
              LanguageLabelKeys.shareOtpWithDeliveryPartnerMessage,
            ),
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          AppSpacing.h10,
          Center(
            child: Row(
              mainAxisSize: .min,
              children: otp
                  .split('')
                  .map(
                    (digit) => Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingXS,
                      ),
                      child: AppText(
                        digit,
                        style: context.tt.headlineSmall?.copyWith(
                          color: context.cs.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          AppSpacing.h10,
          Divider(color: dividerColor, height: 1),
          AppSpacing.h8,
          Row(
            children: [
              Expanded(
                child: _OtpActionButton(
                  icon: AssetsConstants.copyIcon,
                  label: context.translate(LanguageLabelKeys.copyOtp),
                  onTap: () => _copyOtp(context),
                ),
              ),
              Container(width: 1, height: 20, color: dividerColor),
              Expanded(
                child: _OtpActionButton(
                  icon: AssetsConstants.shareIcon,
                  label: context.translate(LanguageLabelKeys.shareOtp),
                  onTap: () => _shareOtp(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OtpActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _OtpActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.r8,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: ThemeConstants.paddingS,
        ),
        child: Row(
          mainAxisAlignment: .center,
          spacing: ThemeConstants.spaceS,
          children: [
            AppSvgIcon(
              icon,
              color: context.cs.primary,
              size: ThemeConstants.iconXS,
            ),
            AppText(
              label,
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pickup-store card shown as its own section — kept separate from
/// [OrderDetailCustomerInfoCard] so the customer's own address never gets
/// mixed up with the store's address.
class OrderDetailPickupStoreCard extends StatelessWidget {
  final OrderData order;
  const OrderDetailPickupStoreCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isPickup =
        DeliveryType.fromApiValue(order.deliveryType) == DeliveryType.pickup;
    final pickupStore = order.pickupStore;
    if (!isPickup || pickupStore == null) return const SizedBox.shrink();
    return OrderPickupStoreCard(store: pickupStore);
  }
}

class OrderDetailCustomerInfoCard extends StatelessWidget {
  final OrderData order;
  final Widget? footer;
  const OrderDetailCustomerInfoCard({
    super.key,
    required this.order,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final fullAddress = order.orderAddress.hasValue ? order.orderAddress! : '';
    final orderIdText = order.orderNumber?.toString() ?? '';
    final customerLine = [
      if (order.userName.hasValue) order.userName!,
      if (order.mobile.hasValue) order.mobile!,
    ].join(' · ');
    final isPickup =
        DeliveryType.fromApiValue(order.deliveryType) == DeliveryType.pickup;

    final rows = <Widget>[
      OrderDetailLabelValueRow(
        label: context.translate(LanguageLabelKeys.orderId),
        value: orderIdText,
        trailing: orderIdText.isEmpty
            ? null
            : InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: orderIdText));
                  AppSnackBar.show(
                    context: context,
                    message: context.translate(LanguageLabelKeys.copied),
                    type: SnackBarType.success,
                  );
                },
                child: AppSvgIcon(
                  AssetsConstants.copyIcon,
                  size: ThemeConstants.iconXS,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
      ),
      if (order.paymentMethod.hasValue)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.paymentMethod),
          value: formatOrderPaymentMethod(context, order.paymentMethod!),
        ),
      if (customerLine.isNotEmpty)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.customerInfo),
          value: customerLine,
        ),
      if (!isPickup && fullAddress.isNotEmpty)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.deliverTo),
          value: fullAddress,
          maxLines: 2,
        ),
      if (order.address?.billingSameAsShipping == 0 &&
          order.address?.billing != null)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.billingAddress),
          value: formatBillingAddress(order.address!.billing!),
          maxLines: 3,
        ),
      // Business buyer details frozen on the order (null on a consumer
      // order → no rows). The number's label is the order's own
      // buyer_tax_label — the wording it was issued under — never the
      // current country_setting label and never a hardcoded "GST".
      if (order.buyerBusinessName.hasValue)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.businessName),
          value: order.buyerBusinessName!,
          maxLines: 2,
        ),
      if (order.buyerTaxNumber.hasValue)
        OrderDetailLabelValueRow(
          label: order.buyerTaxLabel.hasValue ? order.buyerTaxLabel! : '',
          value: order.buyerTaxNumber!,
        ),
      if (order.date.hasValue)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.orderPlaced),
          value:
              '${context.translate(LanguageLabelKeys.placedOn)} ${AppDateFormatter.formatDateTime(order.date!)}',
        ),
      if (order.cancellationReason.hasValue)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.cancellationReason),
          value: order.cancellationReason!,
          maxLines: 3,
        ),
    ];

    return OrderDetailInfoCard(rows: rows, footer: footer);
  }
}

class OrderDetailItemsCard extends StatelessWidget {
  final List<OrderItems> items;
  final String? currency;
  final OrderData order;

  /// One-time attention pulse on every rating-eligible item's rating
  /// control — see [OrderDetailScreen.highlightRating].
  final bool highlightRating;

  const OrderDetailItemsCard({
    super.key,
    required this.items,
    this.currency,
    required this.order,
    this.highlightRating = false,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          OrderDetailSectionTitle(
            title:
                '${context.translate(LanguageLabelKeys.items)} (${items.length})',
          ),
          AppSpacing.h12,
          Builder(
            builder: (context) {
              // Same product id can appear as multiple order line-items
              // (e.g. split quantities). Rating is product-level, so only
              // the LAST occurrence of a product id shows the rating
              // control — earlier duplicates stay silent on rating.
              final lastIndexByProductId = <int, int>{};
              for (var idx = 0; idx < items.length; idx++) {
                final pid = items[idx].productId;
                if (pid != null) lastIndexByProductId[pid] = idx;
              }
              return Column(
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final pid = item.productId;
                  final showRatingControl =
                      pid == null || lastIndexByProductId[pid] == i;
                  final highlightThis = highlightRating && showRatingControl;
                  return _OrderDetailItemRowSlot(
                    item: item,
                    currency: currency,
                    order: order,
                    showRatingControl: showRatingControl,
                    isLast: i == items.length - 1,
                    highlightRating: highlightThis,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderDetailItemRowSlot extends StatelessWidget {
  final OrderItems item;
  final String? currency;
  final OrderData order;
  final bool showRatingControl;
  final bool isLast;
  final bool highlightRating;
  const _OrderDetailItemRowSlot({
    required this.item,
    this.currency,
    required this.order,
    required this.showRatingControl,
    required this.isLast,
    this.highlightRating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OrderDetailItemRow(
          item: item,
          currency: currency,
          order: order,
          showRatingControl: showRatingControl,
          highlightRating: highlightRating,
        ),
        if (!isLast) ...[
          AppSpacing.h10,
          Divider(height: 1, color: context.cs.outlineVariant),
          AppSpacing.h10,
        ],
      ],
    );
  }
}

class OrderDetailItemRow extends StatelessWidget {
  final OrderItems item;
  final String? currency;
  final OrderData order;
  final bool showRatingControl;
  final bool highlightRating;
  const OrderDetailItemRow({
    super.key,
    required this.item,
    this.currency,
    required this.order,
    this.showRatingControl = true,
    this.highlightRating = false,
  });

  @override
  Widget build(BuildContext context) {
    final imgSize = context.screenWidth * 0.15;
    final variant =
        VariantAttributesFormatter.format(item.variantAttributes) ?? "";
    final hasImage = item.imageUrl.hasValue;

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceS,
      children: [
        Row(
          crossAxisAlignment: .start,
          children: [
            hasImage
                ? ClipRRect(
                    borderRadius: AppRadius.r10,
                    child: Container(
                      decoration: AppDecorations.box(
                        color: context.cs.surfaceContainer,
                        border: Border.all(
                          color: context.cs.outline.withValues(alpha: 0.12),
                        ),
                        borderRadius: AppRadius.r10,
                      ),
                      child: AppNetworkImage(
                        url: item.imageUrl!,
                        width: imgSize,
                        height: imgSize,
                        fit: BoxFit.contain,
                        borderRadius: AppRadius.r10,
                      ),
                    ),
                  )
                : ProductImagePlaceholder(size: imgSize),
            AppSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceXXS,
                children: [
                  Text.rich(
                    ProductTypeIcon.nameSpan(
                      productType: item.productType,
                      name: '${item.quantity ?? 1} × ${item.productName ?? ''}',
                      size: ThemeConstants.iconXS,
                    ),
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: .ellipsis,
                  ),
                  if (variant.isNotEmpty)
                    AppText(
                      variant,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  // Add-on module: order snapshot of chosen options,
                  // rendered the same way as the cart.
                  if (item.addons?.isNotEmpty ?? false)
                    CartAddonList(
                      addons: item.addons!,
                      addonTotal: item.addonTotal ?? 0,
                      currency: currency ?? '',
                      decimalPoint: order.decimalPoint ?? 2,
                    ),
                ],
              ),
            ),
            AppSpacing.w8,
            AppText(
              '$currency${item.discountedPrice ?? 0}',
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (item.prescriptionUrl != null && item.prescriptionUrl!.isNotEmpty)
          PrescriptionAttachmentRow(prescriptionUrl: item.prescriptionUrl!),
        Builder(
          builder: (context) {
            final isQuick = order.channel == AppConstants.quick;
            // Quick orders cancel as a whole from the listing screen —
            // per-item cancel only applies to ecommerce.
            final showCancel =
                !isQuick &&
                item.cancelableStatus == 1 &&
                item.activeStatus != OrderStatus.cancelled;
            final returnRequested = item.returnRequested;
            final returnEligible =
                item.activeStatus == OrderStatus.delivered &&
                item.returnStatus == 1 &&
                (returnRequested == null || returnRequested == 0);
            // Quick orders don't support returns — offer support chat instead.
            final showReturn = !isQuick && returnEligible;
            final showHelp = isQuick && returnEligible;
            final isRated =
                showRatingControl &&
                order.productRating == true &&
                (item.itemRating?.isNotEmpty ?? false);
            final showRate =
                showRatingControl &&
                order.productRating == true &&
                order.activeStatus == OrderStatus.delivered &&
                item.activeStatus != OrderStatus.cancelled &&
                item.activeStatus != OrderStatus.returned &&
                !showCancel &&
                !returnEligible &&
                !(returnRequested != null && returnRequested != 0) &&
                !isRated;

            if (!showCancel &&
                !showReturn &&
                !showHelp &&
                !showRate &&
                !isRated) {
              return AppSpacing.shrink;
            }

            return Padding(
              padding: const EdgeInsetsDirectional.only(
                top: ThemeConstants.paddingS,
              ),
              child: Row(
                mainAxisAlignment: .end,
                children: [
                  if (showCancel)
                    AppButton(
                      label: context.translate(LanguageLabelKeys.cancel),
                      variant: AppButtonVariant.outline,
                      color: context.cs.errorContainer,
                      fullWidth: false,
                      height: 28,
                      fontSize: 13,
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      onPressed: () async {
                        final reason = await _promptReason(
                          context,
                          context.translate(LanguageLabelKeys.cancel),
                          context.translate(
                            LanguageLabelKeys.cancelItemConfirm,
                          ),
                        );
                        if (reason == null || !context.mounted) return;
                        _runStatusUpdate(
                          context,
                          orderId: order.id?.toString() ?? '',
                          status: '${OrderStatus.cancelled}',
                          orderItemId: item.id?.toString(),
                          from: 'cancel',
                          reason: reason,
                        );
                      },
                    ),
                  if (showReturn)
                    AppButton(
                      label: context.translate(LanguageLabelKeys.returnItem),
                      variant: AppButtonVariant.outline,
                      fullWidth: false,
                      height: 28,
                      fontSize: 13,
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      onPressed: () async {
                        final reason = await _promptReason(
                          context,
                          context.translate(LanguageLabelKeys.returnItem),
                          context.translate(
                            LanguageLabelKeys.returnItemConfirm,
                          ),
                        );
                        if (reason == null || !context.mounted) return;
                        _runStatusUpdate(
                          context,
                          orderId: order.id?.toString() ?? '',
                          status: '${OrderStatus.returned}',
                          orderItemId: item.id?.toString(),
                          from: 'return',
                          reason: reason,
                        );
                      },
                    ),
                  if (showHelp)
                    AppButton(
                      label: context.translate(LanguageLabelKeys.getHelp),
                      variant: AppButtonVariant.outline,
                      fullWidth: false,
                      height: 28,
                      fontSize: 13,
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      prefixIcon: const AppSvgIcon(
                        AssetsConstants.faqIcon,
                        size: ThemeConstants.iconXS,
                      ),
                      onPressed: () async {
                        final conversationId =
                            await resolveAdminConversationId();
                        if (!context.mounted) return;
                        AppNavigator.pushNamed(
                          context,
                          RouteNames.chat,
                          arguments: ChatScreenArgs(
                            chatType: ChatType.adminChat,
                            recipientName: context.translate(
                              LanguageLabelKeys.supportTeam,
                            ),
                            recipientId: 0,
                            orderId: order.id?.toString() ?? '',
                            conversationId: conversationId,
                          ),
                        );
                      },
                    ),
                  if (showRate || isRated)
                    Expanded(
                      child: _ItemRatingControl(
                        item: item,
                        isRated: isRated,
                        highlight: highlightRating && !isRated,
                        onRatingChanged: (data) =>
                            context.read<OrderDetailCubit>().applyItemRating(
                              item.id,
                              ItemRating.fromJson(data),
                            ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 5-star row + label, shared by the unrated and already-rated states.
/// Tapping a star always submits that rate directly (add if unrated, update
/// if rated). Tapping the label opens the full bottom sheet for review text
/// and photos.
class _ItemRatingControl extends StatefulWidget {
  final OrderItems item;
  final bool isRated;
  final ValueChanged<Map<String, dynamic>> onRatingChanged;

  /// Plays a one-time attention pulse (subtle double scale + glow) right
  /// after this control appears, so a customer landing here straight off a
  /// delivered-order hand-off notices it. Never loops — a single settle-in
  /// pulse reads as a nudge, a repeating one reads as nagging.
  final bool highlight;

  const _ItemRatingControl({
    required this.item,
    required this.isRated,
    required this.onRatingChanged,
    this.highlight = false,
  });

  @override
  State<_ItemRatingControl> createState() => _ItemRatingControlState();
}

class _ItemRatingControlState extends State<_ItemRatingControl>
    with SingleTickerProviderStateMixin {
  bool _isSubmitting = false;
  AnimationController? _pulseController;
  Animation<double>? _pulseScale;
  final GlobalKey _highlightKey = GlobalKey();

  ItemRating? get _own => widget.isRated ? widget.item.itemRating?.first : null;

  @override
  void initState() {
    super.initState();
    if (widget.highlight) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      );
      _pulseController = controller;
      // Three visible bumps rather than a subtle single one — a faint
      // one-shot tint was easy to miss entirely on first glance.
      _pulseScale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
      // Let the navigation transition settle, then scroll it fully into view
      // (it can land below the fold on smaller screens) before pulsing —
      // otherwise the animation plays off-screen and nobody sees it.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Best-effort — if scrolling into view fails for any reason, the
        // pulse must still play rather than silently never firing.
        try {
          final ctx = _highlightKey.currentContext;
          if (ctx != null) {
            await Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              alignment: 0.2,
            );
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _quickRate(int rate) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final cubit = RatingAddUpdateCubit();
    try {
      await cubit.submit(
        productId: widget.item.productId?.toString() ?? '',
        ratingId: _own?.id,
        rate: rate.toString(),
        review: _own?.review ?? '',
      );
      final state = cubit.state;
      if (state is RatingAddUpdateSuccess && state.data != null) {
        widget.onRatingChanged(state.data!);
      } else if (state is RatingAddUpdateError && mounted) {
        AppSnackBar.show(
          context: context,
          message: state.message,
          type: SnackBarType.error,
        );
      }
    } finally {
      cubit.close();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openSheet() async {
    final own = _own;
    final data = await showRateProductSheet(
      context,
      productId: widget.item.productId?.toString() ?? '',
      productName: widget.item.productName ?? '',
      ratingId: own?.id,
      initialRate: int.tryParse(own?.rate ?? '') ?? 0,
      initialReview: own?.review ?? '',
      initialImages: (own?.images ?? [])
          .map(
            (img) =>
                ExistingRatingImage(id: img.id ?? '', url: img.imageUrl ?? ''),
          )
          .toList(),
    );
    if (data != null && context.mounted) {
      widget.onRatingChanged(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = int.tryParse(_own?.rate ?? '0') ?? 0;
    final hasReview = (_own?.review ?? '').isNotEmpty;
    final labelKey = !widget.isRated
        ? LanguageLabelKeys.rateThisProductNow
        : hasReview
        ? LanguageLabelKeys.viewReview
        : LanguageLabelKeys.writeAReview;

    final row = Row(
      crossAxisAlignment: .center,
      mainAxisSize: .min,
      children: [
        Expanded(
          child: RatingStarsRow(
            currentRate: currentRate,
            isSubmitting: _isSubmitting,
            onRate: _quickRate,
          ),
        ),
        InkWell(
          onTap: _openSheet,
          child: AppText(
            context.translate(labelKey),
            style: context.tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.isRated
                  ? context.cs.primary
                  : context.cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    final pulseController = _pulseController;
    if (pulseController == null) return row;
    return AnimatedBuilder(
      key: _highlightKey,
      animation: pulseController,
      child: row,
      builder: (context, child) {
        final scale = _pulseScale!.value;
        final glowStrength = ((scale - 1.0) / 0.1).clamp(0.0, 1.0);
        // Same yellow RatingStarsRow uses for the stars themselves, so the
        // highlight reads as "this is about rating" rather than a generic
        // theme-color nudge.
        final glowColor = context.cs.onPrimaryFixedVariant;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.18 * glowStrength),
              borderRadius: AppRadius.r8,
              border: Border.all(
                color: glowColor.withValues(alpha: 0.7 * glowStrength),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class OrderDetailPriceSummaryCard extends StatelessWidget {
  final OrderData order;
  final VoidCallback? onDownloadInvoice;
  final bool isDownloadingInvoice;
  const OrderDetailPriceSummaryCard({
    super.key,
    required this.order,
    this.onDownloadInvoice,
    this.isDownloadingInvoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final currency = order.currency;
    final hasDiscount = order.discount != null && order.discount != 0;
    final paymentInfo = resolveOrderPaymentInfo(
      context: context,
      walletUsed: order.paidWallet,
      finalTotal: order.finalTotal,
      rawPaymentMethod: order.paymentMethod,
      isDelivered: order.activeStatus == OrderStatus.delivered,
    );
    final hasWallet = paymentInfo.hasWallet;
    final hasPromo =
        order.promoCode.hasValue && (order.promoDiscount ?? 0) != 0;
    final hasAdditional =
        order.additionalCharges != null && order.additionalCharges!.isNotEmpty;
    final hasSurge =
        order.surgeCharges != null && order.surgeCharges!.isNotEmpty;
    final hasTax =
        order.taxBreakdown?.any(
          (tax) => tax.amount != null && tax.amount != 0,
        ) ??
        false;
    final saved = (order.savedAmount ?? 0) > 0
        ? order.savedAmount!
        : (order.discount ?? 0) + (order.promoDiscount ?? 0);
    final hasCashback =
        order.cashbackCredited == 1 && (order.cashbackAmount ?? 0) > 0;

    return OrderDetailBillSummaryCard(
      currency: currency ?? '',
      onDownloadInvoice: onDownloadInvoice,
      isDownloadingInvoice: isDownloadingInvoice,
      walletValue: (hasWallet && !paymentInfo.isFullyPaidByWallet)
          ? '${order.paidWallet}'
          : null,
      remainingLabel: paymentInfo.isCombined
          ? paymentInfo.remainingRowLabel
          : null,
      remainingValue: paymentInfo.isCombined
          ? (order.finalTotal ?? 0).formatPrice()
          : null,
      totalRowLabel: paymentInfo.totalRowLabel,
      totalRowValue: '$currency${paymentInfo.totalRowAmount.formatPrice()}',
      saved: saved,
      cashbackText: hasCashback
          ? '${context.translate(LanguageLabelKeys.cashback)} $currency${order.cashbackAmount!.formatPrice()}'
          : null,
      cashbackSubtitle: hasCashback
          ? context.translate(LanguageLabelKeys.cashbackCreditedToWallet)
          : null,
      rows: [
        OrderDetailPriceRow(
          label: context.translate(LanguageLabelKeys.subtotal),
          value: '$currency${order.total ?? 0}',
          suffixLabel: hasTax
              ? context.translate(LanguageLabelKeys.inclTax)
              : null,
          suffixTooltipMessage: hasTax
              ? taxBreakdownMessage(
                  context,
                  order.taxBreakdown!,
                  (amount) =>
                      '$currency${amount.formatPrice(order.decimalPoint ?? 2)}',
                )
              : null,
          suffixSheetTitle: hasTax
              ? context.translate(LanguageLabelKeys.taxBreakdown)
              : null,
          suffixContentBuilder: hasTax
              ? (sheetContext) => taxBreakdownSheet(
                  sheetContext,
                  order.taxBreakdown!,
                  (amount) =>
                      '$currency${amount.formatPrice(order.decimalPoint ?? 2)}',
                )
              : null,
        ),
        if ((order.deliveryCharge?.amount ?? 0) > 0)
          OrderDetailPriceRow(
            label: context.translate(LanguageLabelKeys.deliveryCharge),
            value: '$currency${order.deliveryCharge?.amount ?? 0}',
            detailContentBuilder:
                hasChargeTaxDetail(
                  taxName: order.deliveryCharge?.taxName,
                  taxAmount: order.deliveryCharge?.taxAmount,
                  taxableAmount: order.deliveryCharge?.taxableAmount,
                  taxRate: order.deliveryCharge?.taxRate,
                )
                ? (sheetContext) => additionalChargeDetailSheet(
                    sheetContext,
                    (amount) =>
                        '$currency${amount.formatPrice(order.decimalPoint ?? 2)}',
                    label: context.translate(LanguageLabelKeys.deliveryCharge),
                    totalAmount: order.deliveryCharge?.amount ?? 0,
                    taxName: order.deliveryCharge?.taxName,
                    taxAmount: order.deliveryCharge?.taxAmount,
                    taxRate: order.deliveryCharge?.taxRate,
                  )
                : null,
          ),
        if (hasDiscount)
          OrderDetailPriceRow(
            label: context.translate(LanguageLabelKeys.discount),
            value: '- $currency${(order.discount ?? 0).formatPrice()}',
            valueColor: context.cs.onSecondaryContainer,
          ),
        if (hasPromo)
          OrderDetailPriceRow(
            label:
                '${context.translate(LanguageLabelKeys.promo)} (${order.promoCode})',
            value: '- $currency${order.promoDiscount ?? 0}',
            valueColor: context.cs.onSecondaryContainer,
          ),
        if (hasAdditional)
          ...order.additionalCharges!.map((charge) {
            final hasTaxDetail = hasChargeTaxDetail(
              taxName: charge.taxName,
              taxAmount: charge.taxAmount,
              taxableAmount: charge.taxableAmount,
              taxRate: charge.taxRate,
            );
            final label =
                charge.name ?? context.translate(LanguageLabelKeys.additional);
            return OrderDetailPriceRow(
              label: label,
              value: '$currency${charge.amount ?? 0}',
              isRefundable: hasTaxDetail ? null : charge.isRefundable,
              detailContentBuilder: hasTaxDetail
                  ? (sheetContext) => additionalChargeDetailSheet(
                      sheetContext,
                      (amount) =>
                          '$currency${amount.formatPrice(order.decimalPoint ?? 2)}',
                      label: label,
                      totalAmount: charge.amount ?? 0,
                      isRefundable: charge.isRefundable,
                      taxName: charge.taxName,
                      taxAmount: charge.taxAmount,
                      taxRate: charge.taxRate,
                    )
                  : null,
            );
          }),
        if (hasSurge)
          ...order.surgeCharges!.map((surge) {
            final hasTaxDetail = hasChargeTaxDetail(
              taxName: surge.taxName,
              taxAmount: surge.taxAmount,
              taxableAmount: surge.taxableAmount,
              taxRate: surge.taxRate,
            );
            final label =
                surge.label ?? context.translate(LanguageLabelKeys.surge);
            return OrderDetailPriceRow(
              label: label,
              value: '$currency${surge.charge ?? 0}',
              isRefundable: hasTaxDetail ? null : surge.isRefundable,
              detailContentBuilder: hasTaxDetail
                  ? (sheetContext) => additionalChargeDetailSheet(
                      sheetContext,
                      (amount) =>
                          '$currency${amount.formatPrice(order.decimalPoint ?? 2)}',
                      label: label,
                      totalAmount: surge.charge ?? 0,
                      isRefundable: surge.isRefundable,
                      taxName: surge.taxName,
                      taxAmount: surge.taxAmount,
                      taxRate: surge.taxRate,
                    )
                  : null,
            );
          }),
      ],
    );
  }
}

class OrderDetailDeliveryBoyCard extends StatelessWidget {
  final OrderData order;
  const OrderDetailDeliveryBoyCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return OrderDetailDeliveryBoyView(
      deliveryBoyName: order.deliveryBoyName ?? '',
      deliveryBoyMobile: order.deliveryBoyMobile,
      showChat: true,
      onChatTap: () async {
        final orderId = order.id?.toString() ?? '';
        final conversationId = await resolveOrderConversationId(orderId);
        if (!context.mounted) return;
        AppNavigator.pushNamed(
          context,
          RouteNames.chat,
          arguments: ChatScreenArgs(
            chatType: ChatType.deliveryBoyChat,
            recipientName: order.deliveryBoyName ?? '',
            recipientId: order.deliveryBoyId ?? 0,
            orderId: orderId,
            conversationId: conversationId,
          ),
        );
      },
    );
  }
}
