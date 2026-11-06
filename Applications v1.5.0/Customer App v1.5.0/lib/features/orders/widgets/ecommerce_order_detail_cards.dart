import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/features/products/widgets/cart_addon_list.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/product_image_placeholder.dart';
import 'package:customer/commons/widgets/tax_breakdown_sheet.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/address/widgets/address_actions.dart';
import 'package:customer/features/address/widgets/address_picker_sheet.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/services/chat_conversation_resolver.dart';
import 'package:customer/features/orders/cubit/ecommerce_order_detail_cubit.dart';
import 'package:customer/features/orders/cubit/order_status_update_cubit.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/features/orders/models/order_model.dart'
    show ItemRating;
import 'package:customer/features/orders/widgets/order_detail_cards.dart'
    show showCancelOrderSheet;
import 'package:customer/features/orders/utils/order_payment_utils.dart';
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Shown only while the order is still on its way — hidden once delivered,
/// cancelled or returned, and hidden when the API sends no date at all.
class EcommerceOrderDetailExpectedDeliveryCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const EcommerceOrderDetailExpectedDeliveryCard({
    super.key,
    required this.order,
  });

  static bool shouldShow(EcommerceOrderDataModel order) {
    final isPickup =
        DeliveryType.fromApiValue(order.deliveryType) == DeliveryType.pickup;
    const finalStatuses = [
      OrderStatus.delivered,
      OrderStatus.cancelled,
      OrderStatus.returned,
      OrderStatus.pickup,
    ];
    return !isPickup &&
        (order.estimatedDeliveryDate?.isNotEmpty ?? false) &&
        !finalStatuses.contains(order.activeStatus);
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(order)) return const SizedBox.shrink();

    return OrderDetailCard(
      child: Row(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceXS,
        children: [
          AppSvgIcon(
            AssetsConstants.expectedDeliveryIcon,
            size: ThemeConstants.iconS,
            color: context.cs.onSurfaceVariant,
          ),
          Text.rich(
            TextSpan(
              text:
                  '${context.translate(LanguageLabelKeys.orderExpectedDeliveryBy)} ',
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: context.cs.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: AppDateFormatter.formatDate(
                    order.estimatedDeliveryDate,
                  ),
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurfaceVariant,
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

class EcommerceOrderDetailReturnRejectCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const EcommerceOrderDetailReturnRejectCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.cs.error.withValues(alpha: 0.14),
            context.cs.error.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: context.cs.error.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: AppDecorations.box(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.cs.error,
                  context.cs.error.withValues(alpha: 0.7),
                ],
              ),
              shape: .circle,
              boxShadow: [
                BoxShadow(
                  color: context.cs.error.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AppSvgIcon(
              AssetsConstants.dangerIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onError,
              fit: BoxFit.scaleDown,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXXS,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.returnRejectReason),
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.error,
                  ),
                ),
                AppText(
                  order.returnRejectReason!,
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
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

/// Pickup-store card shown as its own section — kept separate from
/// [EcommerceOrderDetailCustomerInfoCard] so the customer's own address
/// (billing) never gets mixed up with the store's address.
class EcommerceOrderDetailPickupStoreCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const EcommerceOrderDetailPickupStoreCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isPickup =
        DeliveryType.fromApiValue(order.deliveryType) == DeliveryType.pickup;
    final pickupStore = order.pickupStore;
    if (!isPickup || pickupStore == null) return const SizedBox.shrink();
    return OrderPickupStoreCard(store: pickupStore);
  }
}

class EcommerceOrderDetailCustomerInfoCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const EcommerceOrderDetailCustomerInfoCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final fullAddress = order.address?.address.hasValue ?? false
        ? order.address!.address!
        : '';
    final orderIdText = order.orderNumber?.toString() ?? '';
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
      if (order.address?.mobile.hasValue ?? false)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.mobileNumber),
          value: order.address!.mobile!,
        ),
      if (!isPickup && fullAddress.isNotEmpty)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.deliveryAddress),
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
      if (order.returnReason.hasValue)
        OrderDetailLabelValueRow(
          label: context.translate(LanguageLabelKeys.returnReason),
          value: order.returnReason!,
          maxLines: 3,
        ),
    ];

    return OrderDetailInfoCard(rows: rows);
  }
}

class EcommerceOrderDetailItemsCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  final GlobalKey? otherItemsSectionKey;
  const EcommerceOrderDetailItemsCard({
    super.key,
    required this.order,
    this.otherItemsSectionKey,
  });

  @override
  Widget build(BuildContext context) {
    final otherItems = order.otherItems ?? [];
    final dividerColor = context.cs.outlineVariant;

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        OrderDetailCard(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceM,
            children: [
              OrderDetailSectionTitle(
                title: context.translate(LanguageLabelKeys.items),
              ),
              EcommerceOrderDetailItemRow(order: order),
            ],
          ),
        ),
        if (otherItems.isNotEmpty) ...[
          OrderDetailCard(
            key: otherItemsSectionKey,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                OrderDetailSectionTitle(
                  title: context.translate(LanguageLabelKeys.otherItemsInOrder),
                ),
                AppSpacing.h2,
                AppText(
                  '${context.translate(LanguageLabelKeys.orderId)} ${AppConstants.hashSymbol}${order.orderId ?? ''}',
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h12,
                ...otherItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      _OtherItemRow(
                        item: item,
                        currency: order.currency ?? '',
                        isOngoing:
                            order.activeStatus == OrderStatus.paymentPending,
                      ),
                      if (i < otherItems.length - 1) ...[
                        AppSpacing.h10,
                        Divider(height: 1, color: dividerColor),
                        AppSpacing.h10,
                      ],
                    ],
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

class EcommerceOrderDetailItemRow extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const EcommerceOrderDetailItemRow({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final imgSize = context.screenWidth * 0.15;
    final variant =
        VariantAttributesFormatter.format(order.variantAttributes) ?? '';
    final hasImage = order.image.hasValue;
    final dividerColor = context.cs.outlineVariant;

    final showCancel = order.isCancellable ?? false;
    final orderCreatedAt = AppDateFormatter.parse(order.date);
    final returnDeadline = (orderCreatedAt != null && order.returnDays != null)
        ? orderCreatedAt.add(Duration(days: order.returnDays!))
        : null;
    final returnEligible =
        (order.isReturnable ?? false) &&
        returnDeadline != null &&
        DateTime.now().isBefore(returnDeadline);
    final returnRequested = (order.returnRequested ?? 0) != 0;
    final isRated =
        order.productRating == true && (order.itemRating?.isNotEmpty ?? false);
    final showRate =
        order.productRating == true &&
        order.activeStatus == OrderStatus.delivered &&
        !showCancel &&
        !returnEligible &&
        !returnRequested &&
        !isRated;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
          decoration: AppDecorations.box(
            border: (showRate || isRated)
                ? Border(
                    top: BorderSide(color: dividerColor),
                    left: BorderSide(color: dividerColor),
                    right: BorderSide(color: dividerColor),
                  )
                : Border.all(color: dividerColor),
            borderRadius: (showRate || isRated)
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  )
                : AppRadius.r12,
          ),
          child: Row(
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
                          url: order.image!,
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
                        productType: order.productType,
                        name:
                            '${order.quantity ?? 1} × ${order.productName ?? ''}',
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
                    if (order.addons?.isNotEmpty ?? false)
                      CartAddonList(
                        addons: order.addons!,
                        addonTotal: order.addonTotal ?? 0,
                        currency: order.currency ?? '',
                        decimalPoint: order.decimalPoint ?? 2,
                      ),
                  ],
                ),
              ),
              AppSpacing.w8,
              AppText(
                '${order.currency ?? ''}${order.discountedPrice ?? order.price ?? 0}',
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (order.prescriptionUrl != null &&
            order.prescriptionUrl!.isNotEmpty) ...[
          AppSpacing.h8,
          PrescriptionAttachmentRow(prescriptionUrl: order.prescriptionUrl!),
        ],
        if (((order.prescriptionUrl != null &&
                    order.prescriptionUrl!.isNotEmpty) ||
                returnEligible) &&
            (showCancel || returnEligible || showRate || isRated))
          AppSpacing.h8,
        Builder(
          builder: (context) {
            if (!showCancel && !returnEligible && !showRate && !isRated) {
              return AppSpacing.shrink;
            }

            return SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: .end,
                children: [
                  if (showRate || isRated)
                    EcommerceItemRatingControl(
                      order: order,
                      onRatingChanged: (data) => context
                          .read<EcommerceOrderDetailCubit>()
                          .applyItemRating(ItemRating.fromJson(data)),
                    ),
                  if (showCancel || returnEligible) AppSpacing.h8,
                  if (showCancel || returnEligible)
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: ThemeConstants.spaceM,
                      runSpacing: 8,
                      children: [
                        if (showCancel) _cancelButton(context),
                        if (returnEligible) _returnButton(context),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _cancelButton(BuildContext context) {
    return AppButton(
      label: context.translate(LanguageLabelKeys.cancelItem),
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
        final reason = await showCancelOrderSheet(
          context,
          title: context.translate(LanguageLabelKeys.cancelItem),
          message: context.translate(LanguageLabelKeys.cancelItemConfirm),
          confirmLabel: context.translate(LanguageLabelKeys.cancelItem),
          hint: context.translate(LanguageLabelKeys.enterCancellationReason),
        );
        if (reason == null || !context.mounted) return;
        context.read<OrderStatusUpdateCubit>().updateStatus(
          orderId: order.orderId?.toString() ?? '',
          status: '${OrderStatus.cancelled}',
          orderItemId: order.id?.toString(),
          from: 'cancel',
          reason: reason,
        );
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.requestSubmitted),
          type: SnackBarType.success,
        );
      },
    );
  }

  /// Opens the saved-address picker so the user can choose a pickup address
  /// for the return — returns the chosen address, or null if dismissed.
  Future<AddressData?> _pickReturnAddress(BuildContext context) {
    final addressCubit = AddressCubit()..fetchInitial();
    return showAppBottomSheet<AddressData>(
      context,
      showDragHandle: false,
      padding: null,
      backgroundColor: Colors.transparent,
      navigationBarColor: context.cs.surfaceContainer,
      builder: (_) => BlocProvider.value(
        value: addressCubit,
        child: AddressPickerSheet(
          selectedId: null,
          onSelect: (addr) => AppNavigator.pop(context, addr),
          onAddNew: () {
            AppNavigator.pop(context, null);
            openAddressEditor(context, addressCubit: addressCubit);
          },
        ),
      ),
    );
  }

  Widget _returnButton(BuildContext context) {
    return AppButton(
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
        final address = await _pickReturnAddress(context);
        if (address == null || !context.mounted) return;
        final reason = await showCancelOrderSheet(
          context,
          title: context.translate(LanguageLabelKeys.returnItem),
          message: context.translate(LanguageLabelKeys.returnItemConfirm),
          confirmLabel: context.translate(LanguageLabelKeys.returnItem),
          hint: context.translate(LanguageLabelKeys.enterReturnReason),
        );
        if (reason == null || !context.mounted) return;
        context.read<OrderStatusUpdateCubit>().updateStatus(
          orderId: order.orderId?.toString() ?? '',
          status: '${OrderStatus.returned}',
          orderItemId: order.id?.toString(),
          from: 'return',
          reason: reason,
          addressId: address.id,
        );
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.requestSubmitted),
          type: SnackBarType.success,
        );
      },
    );
  }
}

class _OtherItemRow extends StatelessWidget {
  final OtherItems item;
  final String currency;
  final bool isOngoing;
  const _OtherItemRow({
    required this.item,
    required this.currency,
    required this.isOngoing,
  });

  @override
  Widget build(BuildContext context) {
    final imgSize = context.screenWidth * 0.15;
    final hasImage = item.image.hasValue;

    return InkWell(
      onTap: item.orderItemId == null
          ? null
          : () => AppNavigator.pushNamed(
              context,
              RouteNames.ecommerceOrderDetail,
              arguments: EcommerceOrderDetailArgs(
                orderItemId: item.orderItemId!.toString(),
                isOngoing: isOngoing,
              ),
            ),
      child: Row(
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
                      url: item.image!,
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
                if (item.finalTotal != null) ...[
                  AppSpacing.h2,
                  AppText(
                    '$currency${item.finalTotal!.formatPrice()}',
                    style: context.tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.orderItemId != null)
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                size: ThemeConstants.iconS,
                color: context.cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class EcommerceOrderDetailPriceSummaryCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  final VoidCallback? onDownloadInvoice;
  final bool isDownloadingInvoice;
  const EcommerceOrderDetailPriceSummaryCard({
    super.key,
    required this.order,
    this.onDownloadInvoice,
    this.isDownloadingInvoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final currency = order.currency ?? '';
    final hasPromo = order.promoDiscount != null && order.promoDiscount != 0;
    final paymentInfo = resolveOrderPaymentInfo(
      context: context,
      walletUsed: order.walletBalance,
      finalTotal: order.finalTotal,
      rawPaymentMethod: order.paymentMethod,
      isDelivered: order.activeStatus == OrderStatus.delivered,
    );
    final hasWallet = paymentInfo.hasWallet;
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
        : (order.promoDiscount ?? 0);
    final hasCashback =
        order.cashbackCredited == 1 && (order.cashbackAmount ?? 0) > 0;

    return OrderDetailBillSummaryCard(
      currency: currency,
      onDownloadInvoice: onDownloadInvoice,
      isDownloadingInvoice: isDownloadingInvoice,
      walletValue: (hasWallet && !paymentInfo.isFullyPaidByWallet)
          ? '${order.walletBalance}'
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
          value: '$currency${order.subTotal ?? 0}',
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
        if (DeliveryType.fromApiValue(order.deliveryType) !=
                DeliveryType.pickup &&
            (order.deliveryCharge?.amount ?? 0) > 0)
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
        if (hasPromo)
          OrderDetailPriceRow(
            label: context.translate(LanguageLabelKeys.discount),
            value: '- $currency${(order.promoDiscount ?? 0).formatPrice()}',
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
            final label = surge.label ?? '';
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

class EcommerceOrderDetailTrackingCard extends StatelessWidget {
  final EcommerceOrderDataModel order;

  /// Shows the return shipment's courier details instead of the forward
  /// delivery's once a return has been requested.
  final bool isReturn;
  const EcommerceOrderDetailTrackingCard({
    super.key,
    required this.order,
    this.isReturn = false,
  });

  String get _courierAgency =>
      (isReturn ? order.returnCourierAgency : order.courierAgency) ?? '';
  String get _trackingId =>
      (isReturn ? order.returnTrackingId : order.trackingId) ?? '';
  String get _trackingUrl =>
      (isReturn ? order.returnTrackingUrl : order.trackingUrl) ?? '';

  Future<void> _openTrackingUrl() async {
    final uri = Uri.tryParse(_trackingUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyTrackingId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _trackingId));
    AppSnackBar.show(
      context: context,
      message: context.translate(LanguageLabelKeys.copied),
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          OrderDetailSectionTitle(
            title: context.translate(LanguageLabelKeys.trackingDetails),
          ),
          Row(
            crossAxisAlignment: .center,
            spacing: ThemeConstants.spaceM,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: context.cs.surfaceContainerHighest,
                child: AppSvgIcon(
                  AssetsConstants.deliveryBikeIcon,
                  size: ThemeConstants.iconM,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXS,
                  children: [
                    AppText(
                      context.translate(LanguageLabelKeys.courierAgency),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    AppText(
                      _courierAgency,
                      style: context.tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_trackingId.isNotEmpty) ...[
            const OrderDetailDivider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceXS,
                    children: [
                      AppText(
                        context.translate(LanguageLabelKeys.trackingId),
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      AppText(
                        _trackingId,
                        style: context.tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: AppRadius.r8,
                  onTap: () => _copyTrackingId(context),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(
                      ThemeConstants.paddingXS,
                    ),
                    child: AppSvgIcon(
                      AssetsConstants.copyIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_trackingUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openTrackingUrl,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.r8),
                ),
                icon: const AppSvgIcon(
                  AssetsConstants.openInNewRoundedIcon,
                  size: ThemeConstants.iconXS,
                ),
                label: AppText(
                  context.translate(LanguageLabelKeys.trackShipment),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EcommerceOrderDetailStoreDeliveryCard extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const EcommerceOrderDetailStoreDeliveryCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return OrderDetailDeliveryBoyView(
      deliveryBoyName: order.deliveryBoyName ?? '',
      deliveryBoyMobile: order.deliveryBoyMobile,
      showChat: order.isDeliveryBoyChatVisible == true,
      onChatTap: () async {
        final orderId = order.orderId?.toString() ?? '';
        final conversationId = await resolveOrderConversationId(
          orderId,
          orderItemId: order.id?.toString(),
        );
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
