import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/features/orders/widgets/bill_summary_card.dart';
import 'package:deliveryboy/features/orders/widgets/product_item_row.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:deliveryboy/utils/variant_attributes_formatter.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/return_order_detail_cubit.dart';
import '../models/return_order_model.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'order_appbar_title.dart';
import 'order_timeline_card.dart';
import 'package:deliveryboy/commons/widgets/section_icon_header.dart';
import 'pickup_delivery_card.dart';
import 'order_status_slide_bar.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class ReturnOrderDetailBody extends StatefulWidget {
  final ReturnRequestData detail;
  const ReturnOrderDetailBody({super.key, required this.detail});

  @override
  State<ReturnOrderDetailBody> createState() => _ReturnOrderDetailBodyState();
}

class _ReturnOrderDetailBodyState extends State<ReturnOrderDetailBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final hideUpdateStatusButton =
        detail.returnStatusEnum == ReturnOrderStatus.returnToSeller ||
        detail.returnStatusEnum == ReturnOrderStatus.rejected ||
        detail.returnStatusEnum == ReturnOrderStatus.cancelled;
    final bottomPad = hideUpdateStatusButton
        ? context.bottomSafePadding
        : ThemeConstants.paddingL;
    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      applyBottomInset: false,
      extendBody: false,
      appBar: CustomAppBar(
        showBackButton: true,
        titleWidget: OrderAppBarTitle(
          statusLabel: detail.orderStatusName ?? '—',
          idLine: detail.returnNumber?.toString() ?? '—',
        ),
        scrollController: _scrollController,
      ),
      bottomNavigationBar: OrderStatusSlideBar.returnOrder(detail: detail),
      body: RefreshIndicator(
        color: context.cs.primary,
        onRefresh: () => context.read<ReturnOrderDetailCubit>().loadDetail(
          detail.id?.toString() ?? '',
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, bottomPad),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              PickupDeliveryCard(
                pickupName:
                    detail.pickupAddress?.name ?? "",
                pickupAddress:
                    detail.pickupAddress?.address ?? "",
                pickupPhone:
                    detail.pickupAddress?.mobile ?? "",
                pickupLatitude:
                    detail.pickupAddress?.latitude ?? "",
                pickupLongitude:
                    detail.pickupAddress?.longitude ?? "",
                deliveryName: detail.storeInfo?.storeName,
                deliveryAddress: detail.storeInfo?.formattedAddress,
                deliveryPhone: detail.storeInfo?.mobile,
                deliveryLatitude: detail.storeInfo?.latitude,
                deliveryLongitude: detail.storeInfo?.longitude,
              ),
              if (detail.timeline?.isNotEmpty ?? false) ...[
                AppSpacing.h12,
                OrderTimelineCard(timeline: detail.timeline!),
              ],
              AppSpacing.h12,
              _ProductCard(detail: detail),
              if (detail.returnReason.isNotNullOrEmpty ||
                  detail.remarks.isNotNullOrEmpty ||
                  detail.rejectReason.isNotNullOrEmpty) ...[
                AppSpacing.h12,
                _ReturnInfoCard(detail: detail),
              ],
              AppSpacing.h12,
              _PaymentCard(detail: detail),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Product ─────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ReturnRequestData detail;
  const _ProductCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final symbol = detail.currency ?? "";

    return Container(
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
          ProductItemRow(
            image: detail.returnItem?.image,
            quantity: detail.quantity,
            productName: detail.productName,
            variantLabel: formatVariantValues(
              detail.returnItem?.variantAttributes,
            ),
            symbol: symbol,
            price: detail.price,
            discountedPrice: detail.discountedPrice,
            addons: detail.returnItem?.addons ?? const [],
            addonTotal: detail.returnItem?.addonTotal ?? 0,
          ),
        ],
      ),
    );
  }
}

// ─── Return info ──────────────────────────────────────────────────────────────

class _ReturnInfoCard extends StatelessWidget {
  final ReturnRequestData detail;
  const _ReturnInfoCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (detail.returnReason.isNotNullOrEmpty ||
              detail.remarks.isNotNullOrEmpty) ...[
            SectionIconHeader(
              icon: AssetsConstants.noteIcon,
              title: context.translate(LanguageLabelKeys.whyReturnQuestion),
            ),
            if (detail.returnReason.isNotNullOrEmpty) ...[
              AppSpacing.h10,
              AppText(
                detail.returnReason!,
                style: context.tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.cs.onSurface,
                ),
              ),
            ],
            if (detail.remarks.isNotNullOrEmpty) ...[
              AppSpacing.h6,
              AppText(
                detail.remarks!,
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
          if (detail.rejectReason.isNotNullOrEmpty) ...[
            if (detail.returnReason.isNotNullOrEmpty ||
                detail.remarks.isNotNullOrEmpty)
              AppSpacing.h12,
            _InfoBlock(
              icon: AssetsConstants.closeCircleIcon,
              label: context.translate(LanguageLabelKeys.cancelReason),
              value: detail.rejectReason!,
              color: context.cs.onErrorContainer,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(10),
      decoration: AppDecorations.card(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.r10,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              AppSvgIcon(icon, size: ThemeConstants.iconXS, color: color),
              AppSpacing.w6,
              AppText(
                label,
                style: context.tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          AppText(
            value,
            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurface),
          ),
        ],
      ),
    );
  }
}

// ─── Payment ──────────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final ReturnRequestData detail;
  const _PaymentCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final symbol = detail.currency ?? "";

    return BillSummaryCard(
      type: BillOrderType.returnOrder,
      returnDetail: detail,
      symbol: symbol,
    );
  }
}
