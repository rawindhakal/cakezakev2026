import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/pickup_store_details.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/cashback_banner.dart';
import 'package:customer/commons/widgets/dashed_underline_tooltip.dart';
import 'package:customer/commons/widgets/saved_amount_banner.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/features/orders/models/order_address_model.dart';
import 'package:customer/features/orders/models/order_model.dart'
    show ItemRating, OrderPickupStore;
import 'package:customer/features/orders/widgets/order_status_timeline.dart';
import 'package:customer/features/orders/widgets/rate_product_sheet.dart';
import 'package:customer/features/products/cubit/rating_add_update_cubit.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// One-line summary of a billing address for the order-detail info card:
/// name and street address.
String formatBillingAddress(OrderAddressModel billing) {
  return [billing.name, billing.address].where((s) => s.hasValue).join(' • ');
}

class OrderDetailCard extends StatelessWidget {
  final Widget child;
  const OrderDetailCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: AppDecorations.box(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.r12,
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class OrderDetailRefundCard extends StatelessWidget {
  final double refundAmount;
  final String currency;
  const OrderDetailRefundCard({
    super.key,
    required this.refundAmount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return CashbackBanner(
      amountText:
          '${context.translate(LanguageLabelKeys.refundAmount)} $currency${refundAmount.formatPrice()}',
      subtitle: context.translate(LanguageLabelKeys.refundCreditedToWallet),
      icon: AssetsConstants.cashBackIcon,
      color: context.cs.inversePrimary,
    );
  }
}

class OrderDetailSectionTitle extends StatelessWidget {
  final String title;
  const OrderDetailSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppText(
      title,
      style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class OrderDetailPriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool? isRefundable;
  final String? suffixLabel;
  final String? tooltipMessage;
  final String? suffixTooltipMessage;
  final String? suffixSheetTitle;
  final WidgetBuilder? suffixContentBuilder;

  /// Overrides the default plain-message tooltip body with structured
  /// content (e.g. tax breakdown rows) for the main [label] tooltip.
  final WidgetBuilder? detailContentBuilder;
  const OrderDetailPriceRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isRefundable,
    this.suffixLabel,
    this.tooltipMessage,
    this.suffixTooltipMessage,
    this.suffixSheetTitle,
    this.suffixContentBuilder,
    this.detailContentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.tt.labelMedium?.copyWith(
      color: context.cs.onSurfaceVariant,
    );
    final refundableMessage = isRefundable != null
        ? context.translate(
            isRefundable!
                ? LanguageLabelKeys.refundable
                : LanguageLabelKeys.notRefundable,
          )
        : null;
    final combinedMessage = [?refundableMessage, ?tooltipMessage].join('\n');
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: .min,
            children: [
              if (detailContentBuilder != null || combinedMessage.isNotEmpty)
                DashedUnderlineTooltip(
                  text: label,
                  message: combinedMessage,
                  contentBuilder: detailContentBuilder,
                  style: labelStyle,
                )
              else
                AppText(label, style: labelStyle),
              if (suffixLabel != null && suffixLabel!.isNotEmpty) ...[
                AppSpacing.w4,
                Flexible(
                  child:
                      suffixTooltipMessage != null &&
                          suffixTooltipMessage!.isNotEmpty
                      ? DashedUnderlineTooltip(
                          text: suffixLabel!,
                          message: suffixTooltipMessage!,
                          sheetTitle: suffixSheetTitle,
                          contentBuilder: suffixContentBuilder,
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        )
                      : AppText(
                          suffixLabel!,
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          overflow: .ellipsis,
                        ),
                ),
              ],
            ],
          ),
        ),
        AppText(
          value,
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor ?? context.cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Plain icon+text invoice-download trigger — no border/background, sits
/// inline next to the bill-summary title instead of a full-width button.
class InvoiceDownloadAction extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  const InvoiceDownloadAction({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: AppRadius.r8,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingXS,
          vertical: ThemeConstants.paddingXS,
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: ThemeConstants.spaceXS,
          children: [
            if (isLoading)
              LoadingWidget(
                size: ThemeConstants.loaderSizeS,
                color: context.cs.primary,
              )
            else
              AppSvgIcon(
                AssetsConstants.downloadIcon,
                size: ThemeConstants.iconXS,
                color: context.cs.primary,
              ),
            AppText(
              context.translate(LanguageLabelKeys.invoice),
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width status banner — solid status color, icon badge, status label,
/// and the timestamp of the most recent timeline entry. Tap opens
/// [showOrderTimelineSheet] with the full history. Used in place of a
/// header/timeline card across order-detail screens (quick + ecommerce) so
/// there's one status UI everywhere.
///
/// [moreItemsCount] is only ever non-zero for ecommerce orders that have
/// other items in the same parent order — quick orders never pass it, so
/// they always render the plain banner below unchanged. When set, a
/// rubber-stamp badge overlays the top-right corner and a "N more item(s) in
/// this order" row is appended underneath.
class OrderTimelineStatusCard extends StatelessWidget {
  final String statusLabel;
  final Color color;
  final List<Timeline>? timeline;
  final String icon;
  final int moreItemsCount;
  final List<String> moreItemsThumbnails;
  final VoidCallback? onMoreItemsTap;

  const OrderTimelineStatusCard({
    super.key,
    required this.statusLabel,
    required this.color,
    this.timeline,
    this.icon = AssetsConstants.orderIcon,
    this.moreItemsCount = 0,
    this.moreItemsThumbnails = const [],
    this.onMoreItemsTap,
  });

  bool get _hasTimeline => timeline?.isNotEmpty ?? false;

  String? get _dateText {
    if (!_hasTimeline) return null;
    final date = timeline!.last.datetime;
    if (!date.hasValue) return null;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final date = _dateText;

    final bannerRadius = moreItemsCount > 0
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          )
        : AppRadius.r16;

    final banner = InkWell(
      onTap: _hasTimeline
          ? () => showOrderTimelineSheet(context, timeline!)
          : null,
      borderRadius: bannerRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
        decoration: AppDecorations.box(
          color: color,
          borderRadius: bannerRadius,
        ),
        child: Row(
          crossAxisAlignment: .center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: AppDecorations.box(
                color: context.cs.onPrimary.withValues(alpha: 0.22),
                shape: .circle,
              ),
              child: AppSvgIcon(
                icon,
                color: context.cs.onPrimary,
                size: ThemeConstants.iconL,
                fit: BoxFit.scaleDown,
              ),
            ),
            AppSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceXS,
                children: [
                  AppText(
                    statusLabel,
                    maxLines: 2,
                    overflow: .ellipsis,
                    style: context.tt.titleSmall?.copyWith(
                      color: context.cs.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (date != null)
                    AppText(
                      '${context.translate(LanguageLabelKeys.on)} ${AppDateFormatter.formatDateTime(date)}',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
            if (_hasTimeline)
              Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: AppSvgIcon(
                  AssetsConstants.arrowRightIcon,
                  color: context.cs.onPrimary,
                  size: ThemeConstants.iconL,
                ),
              ),
          ],
        ),
      ),
    );

    if (moreItemsCount <= 0) return banner;

    const bottomRadius = BorderRadius.only(
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Column(
      crossAxisAlignment: .start,
      children: [
        banner,
        InkWell(
          onTap: onMoreItemsTap,
          borderRadius: bottomRadius,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
            decoration: AppDecorations.box(
              color: Theme.of(context).cardColor,
              borderRadius: bottomRadius,
            ),
            child: Row(
              children: [
                _OverlappingThumbnails(
                  thumbnails: moreItemsThumbnails,
                  fallback: _thumbFallback(context),
                ),
                AppSpacing.w10,
                Expanded(
                  child: AppText(
                    moreItemsCount == 1
                        ? context.translate(
                            LanguageLabelKeys.moreItemInThisOrder,
                          )
                        : '$moreItemsCount ${context.translate(LanguageLabelKeys.moreItemsInThisOrder)}',
                    style: context.tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
                if (onMoreItemsTap != null)
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
          ),
        ),
      ],
    );
  }

  Widget _thumbFallback(BuildContext context) {
    return ColoredBox(
      color: context.cs.surfaceContainerHighest,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.4,
          heightFactor: 0.4,
          child: AppSvgIcon(AssetsConstants.placeholder, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Up to 3 overlapping circular thumbnails (oldest at back, newest on top),
/// used for the "N more items in this order" row.
class _OverlappingThumbnails extends StatelessWidget {
  final List<String> thumbnails;
  final Widget fallback;
  const _OverlappingThumbnails({
    required this.thumbnails,
    required this.fallback,
  });

  static const double _size = 28;
  static const double _overlap = 14;

  @override
  Widget build(BuildContext context) {
    final images = thumbnails.take(3).toList();
    if (images.isEmpty) {
      return ClipOval(
        child: SizedBox(width: _size, height: _size, child: fallback),
      );
    }

    final count = images.length;
    final totalWidth = _size + (count - 1) * (_size - _overlap);

    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        children: List.generate(count, (i) {
          return PositionedDirectional(
            start: i * (_size - _overlap),
            child: Container(
              width: _size,
              height: _size,
              decoration: AppDecorations.box(
                shape: .circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: images[i].isNotEmpty
                    ? AppNetworkImage(url: images[i])
                    : fallback,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Bottom sheet showing the full order-status timeline — shared by order
/// listing cards and order-detail screens (quick + ecommerce).
void showOrderTimelineSheet(BuildContext context, List<Timeline> timeline) {
  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.orderTimeline),
    backgroundColor: Theme.of(context).cardColor,
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingXL,
      ThemeConstants.paddingL,
      ThemeConstants.paddingXL,
      ThemeConstants.paddingXXL + ThemeConstants.paddingXS,
    ),
    builder: (sheetContext) => SingleChildScrollView(
      child: SlideAnimationList(
        crossAxisAlignment: .stretch,
        children: [
          OrderStatusTimeline(
            statusList: timeline,
            isDark: sheetContext.isDark,
          ),
        ],
      ),
    ),
  );
}

/// Label/value pair row with an optional trailing widget — shared by the
/// quick and ecommerce order-detail customer-info cards.
class OrderDetailLabelValueRow extends StatelessWidget {
  const OrderDetailLabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceS,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXS,
            children: [
              AppText(
                label,
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              AppText(
                value,
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: maxLines,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Pickup-store info card for a pickup order — same [PickupStoreDetails]
/// rows used by the checkout bottom bar, boxed in the same white
/// [OrderDetailCard] style as the other order-detail sections.
/// Shared by the quick and ecommerce order-detail customer-info cards.
class OrderPickupStoreCard extends StatelessWidget {
  const OrderPickupStoreCard({super.key, required this.store});

  final OrderPickupStore store;

  @override
  Widget build(BuildContext context) {
    return OrderDetailCard(
      child: PickupStoreDetails(
        storeName: store.branchName,
        address: store.address,
        latitude: store.latitude,
        longitude: store.longitude,
        contactNumber: store.contactNumber,
        preparationTime: store.preparationTime,
        preparationMinutes: store.preparationMinutes,
        isOpenNow: store.isOpenNow,
      ),
    );
  }
}

/// Attached-prescription row — shown on an order item only when its
/// `prescription_url` is non-empty. Tapping opens the image in the shared
/// full-screen viewer. Used by both quick and ecommerce order-detail item
/// rows so there's one prescription UI everywhere.
class PrescriptionAttachmentRow extends StatelessWidget {
  final String prescriptionUrl;
  const PrescriptionAttachmentRow({super.key, required this.prescriptionUrl});

  bool get _isPdf =>
      prescriptionUrl.toLowerCase().split('?').first.endsWith('.pdf');

  Future<void> _open(BuildContext context) async {
    if (_isPdf) {
      final uri = Uri.tryParse(prescriptionUrl);
      if (uri == null) return;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    AppNavigator.pushNamed(
      context,
      RouteNames.fullScreenImageViewer,
      arguments: (<String>[prescriptionUrl], 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: () => _open(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.box(
          color: context.cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: AppRadius.r8,
          border: Border.all(color: context.cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          spacing: ThemeConstants.spaceS,
          children: [
            AppSvgIcon(
              _isPdf ? AssetsConstants.fileIcon : AssetsConstants.imageIcon,
              size: ThemeConstants.iconS,
              color: context.cs.primary,
            ),
            Expanded(
              child: AppText(
                context.translate(LanguageLabelKeys.prescription),
                style: context.tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppText(
              context.translate(LanguageLabelKeys.viewPrescription),
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.primary,
              ),
            ),
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                size: ThemeConstants.iconXS,
                color: context.cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5-star tap row — shared by the ecommerce and quick order-detail rating
/// controls, which otherwise manage their own state/submit logic
/// separately since their surrounding layout and label styling differ.
class RatingStarsRow extends StatelessWidget {
  final int currentRate;
  final bool isSubmitting;
  final ValueChanged<int> onRate;

  const RatingStarsRow({
    super.key,
    required this.currentRate,
    required this.isSubmitting,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: .min,
        children: List.generate(5, (i) {
          final filled = i < currentRate;
          return InkWell(
            borderRadius: AppRadius.r6,
            onTap: isSubmitting ? null : () => onRate(i + 1),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXS,
              ),
              child: AppSvgIcon(
                filled
                    ? AssetsConstants.starFillIcon
                    : AssetsConstants.starBorderIcon,
                size: ThemeConstants.iconL,
                color: filled
                    ? context.cs.onPrimaryFixedVariant
                    : context.cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class OrderDetailDivider extends StatelessWidget {
  const OrderDetailDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: context.cs.outlineVariant);
  }
}

/// Order-detail-header info card — label/value rows separated by dividers,
/// with an optional footer. Shared by the quick and ecommerce order-detail
/// customer-info cards, which only differ in which fields feed the rows.
class OrderDetailInfoCard extends StatelessWidget {
  final List<Widget> rows;
  final Widget? footer;
  const OrderDetailInfoCard({super.key, required this.rows, this.footer});

  @override
  Widget build(BuildContext context) {
    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          OrderDetailSectionTitle(
            title: context.translate(LanguageLabelKeys.orderDetail),
          ),
          AppSpacing.h12,
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) ...[
              AppSpacing.h10,
              const OrderDetailDivider(),
              AppSpacing.h10,
            ],
          ],
          if (footer != null) ...[
            AppSpacing.h12,
            Align(alignment: Alignment.centerLeft, child: footer!),
          ],
        ],
      ),
    );
  }
}

/// Bill-summary shell — title/invoice-download header, price rows, divider,
/// optional wallet-used row, total row, saved-amount banner, cashback
/// banner. Shared by the quick and ecommerce order-detail price-summary
/// cards, which only differ in which rows/values they feed in.
class OrderDetailBillSummaryCard extends StatelessWidget {
  final String currency;
  final List<Widget> rows;
  final VoidCallback? onDownloadInvoice;
  final bool isDownloadingInvoice;
  final String? walletValue;
  final String? remainingLabel;
  final String? remainingValue;
  final String totalRowLabel;
  final String totalRowValue;
  final double saved;
  final String? cashbackText;
  final String? cashbackSubtitle;

  const OrderDetailBillSummaryCard({
    super.key,
    required this.currency,
    required this.rows,
    this.onDownloadInvoice,
    this.isDownloadingInvoice = false,
    this.walletValue,
    this.remainingLabel,
    this.remainingValue,
    required this.totalRowLabel,
    required this.totalRowValue,
    this.saved = 0,
    this.cashbackText,
    this.cashbackSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = context.cs.outlineVariant;
    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        ClipRRect(
          borderRadius: AppRadius.r12,
          child: Container(
            width: double.infinity,
            decoration: AppDecorations.box(
              color: Theme.of(context).cardColor,
              borderRadius: AppRadius.r12,
              boxShadow: [
                BoxShadow(
                  color: context.theme.shadowColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.all(
                    ThemeConstants.paddingL,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          OrderDetailSectionTitle(
                            title: context.translate(
                              LanguageLabelKeys.billSummary,
                            ),
                          ),
                          if (onDownloadInvoice != null)
                            InvoiceDownloadAction(
                              onTap: onDownloadInvoice!,
                              isLoading: isDownloadingInvoice,
                            ),
                        ],
                      ),
                      AppSpacing.h12,
                      Column(
                        crossAxisAlignment: .start,
                        spacing: ThemeConstants.spaceS,
                        children: rows,
                      ),
                      AppSpacing.h12,
                      Divider(height: 1, color: dividerColor),
                      AppSpacing.h12,
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          AppText(
                            totalRowLabel,
                            style: context.tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          AppText(
                            totalRowValue,
                            style: context.tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (walletValue != null) ...[
                        AppSpacing.h12,
                        OrderDetailPriceRow(
                          label:
                              '${context.translate(LanguageLabelKeys.paidVia)} ${context.translate(LanguageLabelKeys.wallet)}',
                          value: '$currency$walletValue',
                          valueColor: context.cs.onSecondaryContainer,
                        ),
                      ],
                      if (remainingValue != null) ...[
                        AppSpacing.h12,
                        OrderDetailPriceRow(
                          label: remainingLabel ?? '',
                          value: '$currency$remainingValue',
                        ),
                      ],
                    ],
                  ),
                ),
                if (saved > 0)
                  SavedAmountBanner(
                    amountText: '$currency${saved.formatPrice()}',
                  ),
              ],
            ),
          ),
        ),
        if (cashbackText != null)
          CashbackBanner(
            amountText: cashbackText!,
            subtitle: cashbackSubtitle ?? '',
          ),
      ],
    );
  }
}

/// Delivery-boy info card — avatar/name/phone row plus an optional
/// "chat with us" section. Shared by the quick and ecommerce order-detail
/// screens, which only differ in whether the chat section shows and where
/// the tap handler routes to.
class OrderDetailDeliveryBoyView extends StatelessWidget {
  final String deliveryBoyName;
  final String? deliveryBoyMobile;
  final bool showChat;
  final VoidCallback onChatTap;

  const OrderDetailDeliveryBoyView({
    super.key,
    required this.deliveryBoyName,
    this.deliveryBoyMobile,
    required this.showChat,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMobile = deliveryBoyMobile.hasValue;

    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
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
                  children: [
                    AppText(
                      "${context.translate(LanguageLabelKeys.iAm)} "
                      "$deliveryBoyName, "
                      "${context.translate(LanguageLabelKeys.yourDeliveryPartner)}",
                      style: context.tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.h2,
                    AppText(
                      context.translate(
                        LanguageLabelKeys.reachingLocationSoonMessage,
                      ),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMobile)
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('tel:$deliveryBoyMobile');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: AppDecorations.box(
                      color: context.cs.primary,
                      shape: .circle,
                    ),
                    child: AppSvgIcon(
                      AssetsConstants.phoneIcon,
                      color: context.cs.onPrimary,
                      size: ThemeConstants.iconS,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                ),
            ],
          ),
          if (showChat) ...[
            AppSpacing.h16,
            AppText(
              context.translate(LanguageLabelKeys.needHelpWithOrder),
              style: context.tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpacing.h12,
            const OrderDetailDivider(),
            AppSpacing.h12,
            InkWell(
              borderRadius: AppRadius.r12,
              onTap: onChatTap,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.cs.surfaceContainerHighest,
                    child: AppSvgIcon(
                      AssetsConstants.supportChatIcon,
                      size: ThemeConstants.iconM,
                    ),
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: ThemeConstants.spaceXXS,
                      children: [
                        AppText(
                          context.translate(LanguageLabelKeys.chatWithUs),
                          style: context.tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          context.translate(LanguageLabelKeys.aboutOrderIssues),
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
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
                      size: ThemeConstants.iconL,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 5-star row + label for rating an ecommerce order item — shared by the
/// order-detail screen and the order-listing card so there's one rating UI
/// everywhere. Tracks its own rating state locally (so it works standalone
/// in a list), and also notifies [onRatingChanged] when provided, so a
/// parent holding richer order state (e.g. the detail cubit) can stay in
/// sync.
class EcommerceItemRatingControl extends StatefulWidget {
  final EcommerceOrderDataModel order;
  final ValueChanged<Map<String, dynamic>>? onRatingChanged;

  const EcommerceItemRatingControl({
    super.key,
    required this.order,
    this.onRatingChanged,
  });

  @override
  State<EcommerceItemRatingControl> createState() =>
      _EcommerceItemRatingControlState();
}

class _EcommerceItemRatingControlState
    extends State<EcommerceItemRatingControl> {
  bool _isSubmitting = false;
  late ItemRating? _own = widget.order.itemRating?.isNotEmpty ?? false
      ? widget.order.itemRating!.first
      : null;

  bool get _isRated => _own != null;

  Future<void> _quickRate(int rate) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final cubit = RatingAddUpdateCubit();
    try {
      await cubit.submit(
        productId: widget.order.productId?.toString() ?? '',
        ratingId: _own?.id,
        rate: rate.toString(),
        review: _own?.review ?? '',
      );
      final state = cubit.state;
      if (state is RatingAddUpdateSuccess && state.data != null) {
        setState(() => _own = ItemRating.fromJson(state.data!));
        widget.onRatingChanged?.call(state.data!);
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
      productId: widget.order.productId?.toString() ?? '',
      productName: widget.order.productName ?? '',
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
    if (data != null && mounted) {
      setState(() => _own = ItemRating.fromJson(data));
      widget.onRatingChanged?.call(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = int.tryParse(_own?.rate ?? '0') ?? 0;
    final hasReview = (_own?.review ?? '').isNotEmpty;
    final labelKey = !_isRated
        ? LanguageLabelKeys.rateThisProductNow
        : hasReview
        ? LanguageLabelKeys.viewReview
        : LanguageLabelKeys.writeAReview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
        vertical: ThemeConstants.paddingS,
      ),
      decoration: AppDecorations.box(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: RatingStarsRow(
              currentRate: currentRate,
              isSubmitting: _isSubmitting,
              onRate: _quickRate,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _openSheet,
            child: AppText(
              context.translate(labelKey),
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
