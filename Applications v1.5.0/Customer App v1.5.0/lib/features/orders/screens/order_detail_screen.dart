import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/orders/cubit/invoice_download_cubit.dart';
import 'package:customer/features/orders/cubit/order_detail_cubit.dart';
import 'package:customer/features/orders/cubit/order_status_update_cubit.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/widgets/order_detail_cards.dart';
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/features/orders/widgets/order_detail_skeleton_loader.dart';
import 'package:customer/features/orders/widgets/order_help_button.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  /// Gates OTP visibility — true only when opened from the Ongoing tab.
  final bool isOngoing;

  /// True only right after a delivered-order-tracking hand-off — plays a
  /// one-time attention pulse on the rating control. See
  /// [OrderDetailArgs.highlightRating].
  final bool highlightRating;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.isOngoing = false,
    this.highlightRating = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Cancels every non-cancelled item via [OrderStatusUpdateCubit]; the
  /// screen's existing listener patches each item into [OrderDetailCubit] as
  /// responses come back, flipping the order itself to cancelled once every
  /// item is done.
  Future<void> _handleCancelOrder(BuildContext context, OrderData order) async {
    final reason = await showCancelOrderSheet(
      context,
      title: context.translate(LanguageLabelKeys.cancelOrder),
      message: context.translate(LanguageLabelKeys.cancelOrderConfirm),
      confirmLabel: context.translate(LanguageLabelKeys.cancelOrder),
      hint: context.translate(LanguageLabelKeys.enterCancellationReason),
    );
    if (reason == null || !context.mounted) return;

    final id = order.id?.toString() ?? '';
    final statusCubit = context.read<OrderStatusUpdateCubit>();
    await Future.wait([
      for (final item in order.items ?? <OrderItems>[])
        if (item.activeStatus != OrderStatus.cancelled)
          statusCubit.updateStatus(
            orderId: id,
            status: '${OrderStatus.cancelled}',
            orderItemId: item.id?.toString(),
            from: 'cancel',
            reason: reason,
          ),
    ]);
    if (!context.mounted) return;

    AppSnackBar.show(
      context: context,
      message: context.translate(LanguageLabelKeys.requestSubmitted),
      type: SnackBarType.success,
    );
  }

  /// Returns the cancelled order to the listing screen so it can move the
  /// order from Ongoing to Completed locally, without a refetch.
  void _popWithResult(BuildContext context) {
    final state = context.read<OrderDetailCubit>().state;
    OrderData? result;
    if (state is OrderDetailLoaded) {
      final order = state.orderDetail;
      final hasReturn =
          order.items?.any((i) => i.returnRequested == 1) ?? false;
      if (order.activeStatus == OrderStatus.cancelled || hasReturn) {
        result = order;
      }
    }
    AppNavigator.pop(context, result);
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
              // Patch the affected item straight from the response instead
              // of refetching the whole order.
              if (state is OrderStatusUpdateLoaded && state.data != null) {
                context.read<OrderDetailCubit>().applyItemStatusUpdate(
                  int.tryParse(state.orderItemId ?? ''),
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
              actions: [OrderHelpButton(orderId: widget.orderId)],
            ),
            body: BlocBuilder<OrderDetailCubit, OrderDetailState>(
              builder: (context, state) {
                if (state is OrderDetailLoading) {
                  return const OrderDetailSkeletonLoader();
                }

                if (state is OrderDetailError) {
                  return EmptyStateWidget(
                    imagePath: AssetsConstants.noOrderFound,
                    title: state.message,
                    subtitle: context.translate(
                      LanguageLabelKeys.pullToRefresh,
                    ),
                    onRetry: () => context
                        .read<OrderDetailCubit>()
                        .loadOrderDetail(widget.orderId),
                  );
                }

                if (state is OrderDetailLoaded) {
                  final order = state.orderDetail;
                  final items = order.items ?? [];

                  return RefreshIndicator(
                    onRefresh: () => context
                        .read<OrderDetailCubit>()
                        .loadOrderDetail(widget.orderId),
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL + context.bottomSafePadding,
                      ),
                      children: [
                        OrderTimelineStatusCard(
                          statusLabel:
                              order.activeStatus == OrderStatus.orderReceived
                              ? order.orderStatusName ?? ""
                              : '${context.translate(LanguageLabelKeys.order)} ${order.orderStatusName ?? ""}',
                          color:
                              order.activeStatus == OrderStatus.paymentPending
                              ? context.cs.errorContainer
                              : context.cs.onSecondaryContainer,
                          timeline: order.timeline,
                          icon: OrderStatusLabels.icon(order.activeStatus),
                        ),
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
                        if (order.pickupStore != null) ...[
                          AppSpacing.h12,
                          OrderDetailPickupStoreCard(order: order),
                        ],
                        AppSpacing.h12,
                        OrderDetailItemsCard(
                          items: items,
                          currency: order.currency,
                          order: order,
                          highlightRating: widget.highlightRating,
                        ),
                        AppSpacing.h12,
                        OrderDetailCustomerInfoCard(
                          order: order,
                          footer: order.isCancellable == true
                              ? BlocBuilder<
                                  OrderStatusUpdateCubit,
                                  OrderStatusUpdateState
                                >(
                                  builder: (context, statusState) {
                                    final isLoading =
                                        statusState is OrderStatusUpdating;
                                    return AppButton(
                                      label: context.translate(
                                        LanguageLabelKeys.cancelOrder,
                                      ),
                                      onPressed: () =>
                                          _handleCancelOrder(context, order),
                                      isLoading: isLoading,
                                      variant: AppButtonVariant.outline,
                                      color: context.cs.error,
                                      fullWidth: false,
                                      height: 28,
                                      fontSize: 13,
                                      contentPadding:
                                          const EdgeInsetsDirectional.symmetric(
                                            horizontal: ThemeConstants.paddingM,
                                            vertical: ThemeConstants.paddingXS,
                                          ),
                                    );
                                  },
                                )
                              : null,
                        ),
                        if (order.orderNote.hasValue) ...[
                          AppSpacing.h12,
                          OrderDetailInstructionCard(note: order.orderNote!),
                        ],
                        AppSpacing.h12,
                        BlocBuilder<InvoiceDownloadCubit, InvoiceDownloadState>(
                          builder: (context, invoiceState) {
                            return OrderDetailPriceSummaryCard(
                              order: order,
                              isDownloadingInvoice:
                                  invoiceState is InvoiceDownloadLoading,
                              onDownloadInvoice: () => context
                                  .read<InvoiceDownloadCubit>()
                                  .downloadQuickInvoice(widget.orderId),
                            );
                          },
                        ),
                        if (order.isDeliveryBoyChatVisible == true) ...[
                          AppSpacing.h12,
                          OrderDetailDeliveryBoyCard(order: order),
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
