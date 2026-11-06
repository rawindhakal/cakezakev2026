import 'package:customer/utils/json_parsers.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/ecommerce_order_model.dart';
import '../models/order_model.dart' show ItemRating;
import '../repositories/order_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

sealed class EcommerceOrderDetailState {}

final class EcommerceOrderDetailInitial extends EcommerceOrderDetailState {}

final class EcommerceOrderDetailLoading extends EcommerceOrderDetailState {}

final class EcommerceOrderDetailLoaded extends EcommerceOrderDetailState {
  final EcommerceOrderDataModel orderDetail;
  EcommerceOrderDetailLoaded(this.orderDetail);
}

final class EcommerceOrderDetailError extends EcommerceOrderDetailState {
  final String message;
  EcommerceOrderDetailError(this.message);
}

class EcommerceOrderDetailCubit extends Cubit<EcommerceOrderDetailState>
    with ApiErrorGuard<EcommerceOrderDetailState> {
  final OrderRepository _repository;

  EcommerceOrderDetailCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(EcommerceOrderDetailInitial());

  Future<void> loadOrderDetail(String orderItemId) async {
    emit(EcommerceOrderDetailLoading());
    await guard(() async {
      final result = await _repository.getEcommerceOrderDetail(orderItemId);
      emit(EcommerceOrderDetailLoaded(result));
    }, onError: (msg) => emit(EcommerceOrderDetailError(msg)));
  }

  /// Patches the item's rating in place from the add/update-rating
  /// response, avoiding a full order-detail reload.
  void applyItemRating(ItemRating rating) {
    final current = state;
    if (current is! EcommerceOrderDetailLoaded) return;
    current.orderDetail.itemRating = [rating];
    emit(EcommerceOrderDetailLoaded(current.orderDetail));
  }

  /// Patches the order item's status fields in place from the
  /// cancel/return-status response, avoiding a full order-detail reload.
  /// An ecommerce order-detail screen shows exactly one order item, so the
  /// response maps onto [orderDetail] directly rather than a list entry.
  void applyStatusUpdate(Map<String, dynamic> data) {
    final current = state;
    if (current is! EcommerceOrderDetailLoaded) return;
    final order = current.orderDetail;
    order.activeStatus = data['active_status'] ?? order.activeStatus;
    order.cancellationReason =
        data['cancellation_reason'] ?? order.cancellationReason;
    order.canceledAt = data['canceled_at'] ?? order.canceledAt;
    order.returnRequested = data['return_requested'] ?? order.returnRequested;
    order.returnReason = data['return_reason'] ?? order.returnReason;
    order.refundAmount = data['refund_amount'] != null
        ? parseDouble(data['refund_amount'])
        : order.refundAmount;
    if (order.activeStatus == OrderStatus.cancelled) {
      order.isCancellable = false;
    }
    if (order.returnRequested == 1) order.isReturnable = false;
    emit(EcommerceOrderDetailLoaded(order));
  }
}
