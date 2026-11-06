import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/orders/cubit/ecommerce_order_detail_cubit.dart';
import 'package:customer/features/orders/cubit/invoice_download_cubit.dart';
import 'package:customer/features/orders/cubit/order_status_update_cubit.dart';
import 'package:customer/features/orders/widgets/ecommerce_order_detail_cards.dart';
import 'package:customer/features/orders/widgets/order_detail_cards.dart'
    show OrderDetailOtpCard;
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/features/orders/widgets/order_detail_skeleton_loader.dart';
import 'package:customer/features/orders/widgets/order_help_button.dart';
import 'package:customer/utils/ensure_visible_and_flash.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class EcommerceOrderDetailScreen extends StatefulWidget {
  final String orderItemId;

  /// Gates OTP visibility — true only when opened from the Ongoing tab.
  final bool isOngoing;

  const EcommerceOrderDetailScreen({
    super.key,
    required this.orderItemId,
    this.isOngoing = false,
  });

  @override
  State<EcommerceOrderDetailScreen> createState() =>
      _EcommerceOrderDetailScreenState();
}

class _EcommerceOrderDetailScreenState
    extends State<EcommerceOrderDetailScreen> {
  final GlobalKey _otherItemsSectionKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToOtherItems() {
    ensureVisibleAndFlash(
      context,
      _otherItemsSectionKey,
      color: context.cs.primary,
    );
  }

  /// Returns the changed item to the listing screen so it can move it from
  /// Ongoing to Completed (cancel) or patch it in place (return) locally,
  /// without a refetch.
  void _popWithResult(BuildContext context) {
    final state = context.read<EcommerceOrderDetailCubit>().state;
    final order = state is EcommerceOrderDetailLoaded
        ? state.orderDetail
        : null;
    final changed =
        order != null &&
        (order.activeStatus == OrderStatus.cancelled ||
            order.returnRequested == 1);
    AppNavigator.pop(context, changed ? order : null);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OrderStatusUpdateCubit>(
          create: (_) => OrderStatusUpdateCubit(),
        ),
        BlocProvider<InvoiceDownloadCubit>(
          create: (_) => InvoiceDownloadCubit(),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<OrderStatusUpdateCubit, OrderStatusUpdateState>(
            listener: (context, state) {
              if (state is OrderStatusUpdateLoaded && state.data != null) {
                context.read<EcommerceOrderDetailCubit>().applyStatusUpdate(
                  state.data!,
                );
              } else if (state is OrderStatusUpdateError) {
                AppSnackBar.show(
                  context: context,
                  message: state.message,
                  type: SnackBarType.error,
                );
              }
            },
          ),
          BlocListener<InvoiceDownloadCubit, InvoiceDownloadState>(
            listener: (context, state) async {
              if (state is InvoiceDownloadLoaded) {
                await OpenFile.open(state.file.path);
              } else if (state is InvoiceDownloadError) {
                AppSnackBar.show(
                  context: context,
                  message: state.message,
                  type: SnackBarType.error,
                );
              }
            },
          ),
        ],
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _popWithResult(context);
          },
          child: AppScaffold(
            applyBottomInset: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: CustomAppBar(
              title: context.translate(LanguageLabelKeys.orderDetail),
              showBackButton: true,
              onBackPressed: () => _popWithResult(context),
              scrollController: _scrollController,
              actions: [
                BlocBuilder<
                  EcommerceOrderDetailCubit,
                  EcommerceOrderDetailState
                >(
                  builder: (context, state) {
                    final id = state is EcommerceOrderDetailLoaded
                        ? state.orderDetail.orderId?.toString()
                        : null;
                    if (id == null || id.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return OrderHelpButton(orderId: id);
                  },
                ),
              ],
            ),
            body: BlocBuilder<EcommerceOrderDetailCubit, EcommerceOrderDetailState>(
              builder: (context, state) {
                if (state is EcommerceOrderDetailLoading) {
                  return const OrderDetailSkeletonLoader();
                }

                if (state is EcommerceOrderDetailError) {
                  return EmptyStateWidget(
                    imagePath: AssetsConstants.noOrderFound,
                    title: state.message,
                    subtitle: context.translate(
                      LanguageLabelKeys.pullToRefresh,
                    ),
                    onRetry: () => context
                        .read<EcommerceOrderDetailCubit>()
                        .loadOrderDetail(widget.orderItemId),
                  );
                }

                if (state is EcommerceOrderDetailLoaded) {
                  final order = state.orderDetail;
                  final hasDeliveryBoy =
                      order.deliveryBoyName.hasValue &&
                      (order.isDeliveryBoyChatVisible == true ||
                          (order.activeStatus != OrderStatus.delivered &&
                              order.activeStatus != OrderStatus.cancelled &&
                              order.activeStatus != OrderStatus.returned));
                  final hasTrackingInfo =
                      order.activeStatus != OrderStatus.delivered &&
                      order.activeStatus != OrderStatus.pickup &&
                      order.activeStatus != OrderStatus.cancelled &&
                      order.activeStatus != OrderStatus.returned &&
                      (order.courierAgency ?? '').isNotEmpty &&
                      (order.trackingId ?? '').isNotEmpty &&
                      (order.trackingUrl ?? '').isNotEmpty;
                  // Return shipment tracking replaces forward tracking after a
                  // return request, and hides once the refund is credited
                  // (non-zero refund amount) or the return flow completes —
                  // courier isn't needed then.
                  final hasReturnTrackingInfo =
                      (order.refundAmount ?? 0) <= 0 &&
                      order.activeStatus != OrderStatus.returned &&
                      (order.returnCourierAgency ?? '').isNotEmpty;
                  final hasReturnRejectReason =
                      order.returnRejectReason.hasValue;

                  return RefreshIndicator(
                    onRefresh: () => context
                        .read<EcommerceOrderDetailCubit>()
                        .loadOrderDetail(widget.orderItemId),
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Keep every child built regardless of scroll
                      // position — otherwise a target card outside the
                      // default cacheExtent gets unmounted, and its
                      // GlobalKey.currentContext goes null, silently
                      // breaking Scrollable.ensureVisible.
                      // A literal `double.infinity` here makes the viewport
                      // compute a non-finite paint/semantics rect and
                      // crashes with accessibility/semantics enabled — use
                      // a large finite value instead.
                      scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
                      padding: EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL + context.bottomSafePadding,
                      ),
                      children: [
                        OrderTimelineStatusCard(
                          statusLabel:
                              '${context.translate(LanguageLabelKeys.item)} ${order.orderItemStatus ?? (order.activeStatus == OrderStatus.paymentPending ? 'Ongoing' : 'Completed')}',
                          color:
                              order.activeStatus == OrderStatus.paymentPending
                              ? context.cs.errorContainer
                              : context.cs.onSecondaryContainer,
                          timeline: order.timeline,
                          icon: OrderStatusLabels.icon(order.activeStatus),
                          moreItemsCount: order.otherItems?.length ?? 0,
                          moreItemsThumbnails: (order.otherItems ?? [])
                              .map((item) => item.image ?? '')
                              .toList(),
                          onMoreItemsTap:
                              (order.otherItems?.isNotEmpty ?? false)
                              ? _scrollToOtherItems
                              : null,
                        ),
                        if (EcommerceOrderDetailExpectedDeliveryCard.shouldShow(
                          order,
                        )) ...[
                          AppSpacing.h12,
                          EcommerceOrderDetailExpectedDeliveryCard(
                            order: order,
                          ),
                        ],
                        if (hasReturnRejectReason) ...[
                          AppSpacing.h12,
                          EcommerceOrderDetailReturnRejectCard(order: order),
                        ],
                        if ((order.refundAmount ?? 0) > 0) ...[
                          AppSpacing.h12,
                          OrderDetailRefundCard(
                            refundAmount: order.refundAmount!,
                            currency: order.currency ?? '',
                          ),
                        ],
                        if (widget.isOngoing &&
                            order.otp != null &&
                            order.otp != 0) ...[
                          AppSpacing.h12,
                          OrderDetailOtpCard(otp: order.otp!.toString()),
                        ],
                        if (hasReturnTrackingInfo) ...[
                          AppSpacing.h12,
                          EcommerceOrderDetailTrackingCard(
                            order: order,
                            isReturn: true,
                          ),
                        ] else if (hasTrackingInfo) ...[
                          AppSpacing.h12,
                          EcommerceOrderDetailTrackingCard(order: order),
                        ],
                        if (order.pickupStore != null) ...[
                          AppSpacing.h12,
                          EcommerceOrderDetailPickupStoreCard(order: order),
                        ],
                        AppSpacing.h12,
                        EcommerceOrderDetailItemsCard(
                          order: order,
                          otherItemsSectionKey: _otherItemsSectionKey,
                        ),
                        AppSpacing.h12,
                        EcommerceOrderDetailCustomerInfoCard(order: order),
                        AppSpacing.h12,
                        BlocBuilder<InvoiceDownloadCubit, InvoiceDownloadState>(
                          builder: (context, invoiceState) {
                            return EcommerceOrderDetailPriceSummaryCard(
                              order: order,
                              isDownloadingInvoice:
                                  invoiceState is InvoiceDownloadLoading,
                              onDownloadInvoice: () => context
                                  .read<InvoiceDownloadCubit>()
                                  .downloadEcommerceInvoice(widget.orderItemId),
                            );
                          },
                        ),
                        if (hasDeliveryBoy) ...[
                          AppSpacing.h12,
                          EcommerceOrderDetailStoreDeliveryCard(order: order),
                        ],
                        AppSpacing.h8,
                      ],
                    ),
                  );
                }

                return AppSpacing.shrink;
              },
            ),
          ),
        ),
      ),
    );
  }
}
