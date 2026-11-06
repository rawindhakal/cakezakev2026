import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/slide_to_confirm_button.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_update_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_request_order_status_update_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';
import 'package:deliveryboy/features/orders/models/order_status.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart'
    show ReturnOrderStatus, ReturnRequestData;
import 'package:deliveryboy/features/orders/widgets/delivery_otp_bottom_sheet.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which "advance to next status" flow a [OrderStatusSlideBar] drives.
enum OrderStatusType { normal, ecommerce, returnOrder }

/// Single button that advances an order/return-request straight to the next
/// status in the sequence returned by its status-list API. No picker is
/// shown — only the active next status can be applied.
///
/// This widget only orchestrates which existing flow (cubits + business
/// rules) runs, based on [OrderStatusType]; each flow keeps its original
/// cubits, API calls, OTP handling and navigation untouched.
class OrderStatusSlideBar extends StatelessWidget {
  final OrderStatusType type;
  final OrderDetailData? orderDetail;
  final EcommerceOrderDataModel? ecommerceOrder;
  final ReturnRequestData? returnRequest;

  const OrderStatusSlideBar.normal({super.key, required OrderDetailData detail})
    : type = OrderStatusType.normal,
      orderDetail = detail,
      ecommerceOrder = null,
      returnRequest = null;

  const OrderStatusSlideBar.ecommerce({
    super.key,
    required EcommerceOrderDataModel order,
  }) : type = OrderStatusType.ecommerce,
       ecommerceOrder = order,
       orderDetail = null,
       returnRequest = null;

  const OrderStatusSlideBar.returnOrder({
    super.key,
    required ReturnRequestData detail,
  }) : type = OrderStatusType.returnOrder,
       returnRequest = detail,
       orderDetail = null,
       ecommerceOrder = null;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case OrderStatusType.normal:
        return _NormalOrderStatusSlideBar(detail: orderDetail!);
      case OrderStatusType.ecommerce:
        return _EcommerceOrderStatusSlideBar(order: ecommerceOrder!);
      case OrderStatusType.returnOrder:
        return _ReturnOrderStatusSlideBar(detail: returnRequest!);
    }
  }
}

/// Shared bottom slide-to-confirm bar used by all three flows. Purely
/// presentational — callers own their own cubits/models and only pass down
/// primitives.
class OrderStatusSlideConfirmBar extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onConfirm;

  const OrderStatusSlideConfirmBar({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.bottomSafePadding;
    return ColoredBox(
      color: context.cs.surface,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          bottomPad + 12,
        ),
        child: SlideToConfirmButton(
          label: label,
          isLoading: isLoading,
          onConfirm: onConfirm,
        ),
      ),
    );
  }
}

/// Normal-order flow: advances via [OrderStatusListCubit] /
/// [OrderStatusUpdateCubit], asking for a delivery OTP when required.
class _NormalOrderStatusSlideBar extends StatelessWidget {
  final OrderDetailData detail;
  const _NormalOrderStatusSlideBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => OrderStatusListCubit()..loadStatuses()),
        BlocProvider(create: (_) => OrderStatusUpdateCubit()),
      ],
      child: _NormalOrderStatusAction(detail: detail),
    );
  }
}

class _NormalOrderStatusAction extends StatelessWidget {
  final OrderDetailData detail;
  const _NormalOrderStatusAction({required this.detail});

  @override
  Widget build(BuildContext context) {
    final orderId = detail.order?.orderId?.toString() ?? '';
    return BlocListener<OrderStatusUpdateCubit, OrderStatusUpdateState>(
      listener: (ctx, state) {
        if (state is OrderStatusUpdateLoaded) {
          context.read<OrderDetailCubit>().loadOrder(orderId);
          AppSnackBar.show(
            context: context,
            message: context.translate(LanguageLabelKeys.orderStatusUpdated),
            type: SnackBarType.success,
          );
        } else if (state is OrderStatusUpdateError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      child: BlocBuilder<OrderStatusListCubit, OrderStatusListState>(
        builder: (ctx, listState) {
          if (listState is! OrderStatusListLoaded) {
            return const SizedBox.shrink();
          }

          final statuses = listState.data;
          final currentIndex = statuses.indexWhere(
            (s) => s.id == detail.order?.activeStatus?.toString(),
          );
          final nextIndex = currentIndex + 1;
          if (nextIndex >= statuses.length) return const SizedBox.shrink();

          final next = statuses[nextIndex];
          final expectedOtp = detail.order?.otp;
          // OTP is only asked for when the backend actually issued one — a null
          // or 0 OTP means delivery can be confirmed without verification.
          final requiresOtp =
              OrderStatus.fromValue(next.id) == OrderStatus.delivered &&
              expectedOtp != null &&
              expectedOtp != 0;
          return BlocBuilder<OrderStatusUpdateCubit, OrderStatusUpdateState>(
            builder: (ctx2, updateState) {
              final isUpdating = updateState is OrderStatusUpdating;
              return OrderStatusSlideConfirmBar(
                label:
                    '${context.translate(LanguageLabelKeys.markAs)} ${next.statusName ?? ''}',
                isLoading: isUpdating,
                onConfirm: isUpdating
                    ? null
                    : () async {
                        String? verifiedOtp;
                        if (requiresOtp) {
                          verifiedOtp = await showDeliveryOtpBottomSheet(
                            context: ctx2,
                            expectedOtp: expectedOtp,
                          );
                          if (verifiedOtp == null) return;
                        }
                        if (!ctx2.mounted) return;
                        ctx2.read<OrderStatusUpdateCubit>().updateStatus(
                          orderId: orderId,
                          orderStatus: next.id ?? '',
                          otp: verifiedOtp,
                        );
                      },
              );
            },
          );
        },
      ),
    );
  }
}

/// Ecommerce-order flow: advances via [OrderStatusListCubit] (ecommerce
/// channel) / [OrderStatusUpdateCubit], asking for a delivery OTP when
/// required.
class _EcommerceOrderStatusSlideBar extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const _EcommerceOrderStatusSlideBar({required this.order});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              OrderStatusListCubit()
                ..loadStatuses(channel: AppConstants.ecommerce),
        ),
        BlocProvider(create: (_) => OrderStatusUpdateCubit()),
      ],
      child: _EcommerceOrderStatusAction(order: order),
    );
  }
}

class _EcommerceOrderStatusAction extends StatelessWidget {
  final EcommerceOrderDataModel order;
  const _EcommerceOrderStatusAction({required this.order});

  @override
  Widget build(BuildContext context) {
    final orderItemId = order.id?.toString() ?? '';
    return BlocListener<OrderStatusUpdateCubit, OrderStatusUpdateState>(
      listener: (ctx, state) {
        if (state is OrderStatusUpdateLoaded) {
          context.read<EcommerceOrderDetailCubit>().loadOrderDetail(
            orderItemId,
          );
          AppSnackBar.show(
            context: context,
            message: context.translate(LanguageLabelKeys.orderStatusUpdated),
            type: SnackBarType.success,
          );
        } else if (state is OrderStatusUpdateError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      child: BlocBuilder<OrderStatusListCubit, OrderStatusListState>(
        builder: (ctx, listState) {
          if (listState is! OrderStatusListLoaded) {
            return const SizedBox.shrink();
          }

          final statuses = listState.data;
          final currentIndex = statuses.indexWhere(
            (s) => s.id == order.activeStatus?.toString(),
          );
          final nextIndex = currentIndex + 1;
          if (nextIndex >= statuses.length) return const SizedBox.shrink();

          final next = statuses[nextIndex];
          final expectedOtp = order.otp;
          // OTP is only asked for when the backend actually issued one — a null
          // or 0 OTP means delivery can be confirmed without verification.
          final requiresOtp =
              OrderStatus.fromValue(next.id) == OrderStatus.delivered &&
              expectedOtp != null &&
              expectedOtp != 0;
          return BlocBuilder<OrderStatusUpdateCubit, OrderStatusUpdateState>(
            builder: (ctx2, updateState) {
              final isUpdating = updateState is OrderStatusUpdating;
              return OrderStatusSlideConfirmBar(
                label:
                    '${context.translate(LanguageLabelKeys.markAs)} ${next.statusName ?? ''}',
                isLoading: isUpdating,
                onConfirm: isUpdating
                    ? null
                    : () async {
                        String? verifiedOtp;
                        if (requiresOtp) {
                          verifiedOtp = await showDeliveryOtpBottomSheet(
                            context: ctx2,
                            expectedOtp: expectedOtp,
                          );
                          if (verifiedOtp == null) return;
                        }
                        if (!ctx2.mounted) return;
                        ctx2.read<OrderStatusUpdateCubit>().updateItemStatus(
                          orderItemId: orderItemId,
                          orderStatus: next.id ?? '',
                          otp: verifiedOtp,
                        );
                      },
              );
            },
          );
        },
      ),
    );
  }
}

/// Return-request flow: advances via [ReturnOrderStatusListCubit] /
/// [ReturnRequestOrderStatusUpdateCubit]. No OTP step.
class _ReturnOrderStatusSlideBar extends StatelessWidget {
  final ReturnRequestData detail;
  const _ReturnOrderStatusSlideBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ReturnOrderStatusListCubit()..loadStatuses(),
        ),
        BlocProvider(create: (_) => ReturnRequestOrderStatusUpdateCubit()),
      ],
      child: _ReturnOrderStatusAction(detail: detail),
    );
  }
}

class _ReturnOrderStatusAction extends StatelessWidget {
  final ReturnRequestData detail;
  const _ReturnOrderStatusAction({required this.detail});

  @override
  Widget build(BuildContext context) {
    final returnRequestId = detail.id?.toString() ?? '';
    return BlocListener<
      ReturnRequestOrderStatusUpdateCubit,
      ReturnRequestOrderStatusUpdateState
    >(
      listener: (ctx, state) {
        if (state is ReturnRequestOrderStatusUpdateLoaded) {
          context.read<ReturnOrderDetailCubit>().loadDetail(
            returnRequestId.toString(),
          );
          AppSnackBar.show(
            context: context,
            message: context.translate(LanguageLabelKeys.orderStatusUpdated),
            type: SnackBarType.success,
          );
        } else if (state is ReturnRequestOrderStatusUpdateError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      child: BlocBuilder<ReturnOrderStatusListCubit, ReturnOrderStatusListState>(
        builder: (ctx, listState) {
          if (listState is! ReturnOrderStatusListLoaded) {
            return const SizedBox.shrink();
          }
          if (detail.returnStatusEnum == ReturnOrderStatus.returnToSeller ||
              detail.returnStatusEnum == ReturnOrderStatus.rejected) {
            return const SizedBox.shrink();
          }

          final statuses = listState.data;
          final currentIndex = statuses.indexWhere(
            (s) => s.id == detail.status?.toString(),
          );
          final nextIndex = currentIndex + 1;
          if (nextIndex >= statuses.length) return const SizedBox.shrink();

          final next = statuses[nextIndex];
          return BlocBuilder<
            ReturnRequestOrderStatusUpdateCubit,
            ReturnRequestOrderStatusUpdateState
          >(
            builder: (ctx2, updateState) {
              final isUpdating =
                  updateState is ReturnRequestOrderStatusUpdating;
              return OrderStatusSlideConfirmBar(
                label:
                    '${context.translate(LanguageLabelKeys.markAs)} ${next.statusName ?? ''}',
                isLoading: isUpdating,
                onConfirm: isUpdating
                    ? null
                    : () => ctx2
                          .read<ReturnRequestOrderStatusUpdateCubit>()
                          .updateReturnRequestOrderStatus(
                            returnRequestId: returnRequestId.toString(),
                            orderStatus: next.id ?? '',
                          ),
              );
            },
          );
        },
      ),
    );
  }
}
