import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/order_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

sealed class OrderDetailState {}

final class OrderDetailInitial extends OrderDetailState {}

final class OrderDetailLoading extends OrderDetailState {}

final class OrderDetailLoaded extends OrderDetailState {
  final OrderData orderDetail;
  OrderDetailLoaded(this.orderDetail);
}

final class OrderDetailError extends OrderDetailState {
  final String message;
  OrderDetailError(this.message);
}

class OrderDetailCubit extends Cubit<OrderDetailState>
    with ApiErrorGuard<OrderDetailState> {
  final OrderRepository _repository;

  OrderDetailCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(OrderDetailInitial());

  Future<void> loadOrderDetail(String orderId) async {
    emit(OrderDetailLoading());
    await guard(() async {
      final result = await _repository.getOrderDetail(orderId);
      emit(OrderDetailLoaded(result));
    }, onError: (msg) => emit(OrderDetailError(msg)));
  }

  /// Patches a single item's rating in place from the add/update-rating
  /// response, avoiding a full order-detail reload.
  void applyItemRating(int? orderItemId, ItemRating rating) {
    final current = state;
    if (current is! OrderDetailLoaded) return;
    final item = current.orderDetail.items?.firstWhere(
      (i) => i.id == orderItemId,
      orElse: () => OrderItems(),
    );
    if (item == null || item.id != orderItemId) return;
    item.itemRating = [rating];
    emit(OrderDetailLoaded(current.orderDetail));
  }

  /// Patches a single item in place from the cancel/return-status response,
  /// avoiding a full order-detail reload. Also flips the order itself to
  /// cancelled once every item has been cancelled.
  ///
  /// `data` is the order-level response object (has an `items` array),
  /// not a single item — the matching item must be pulled out of it.
  void applyItemStatusUpdate(int? orderItemId, Map<String, dynamic> data) {
    final current = state;
    if (current is! OrderDetailLoaded) return;
    final items = current.orderDetail.items;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == orderItemId);
    if (index == -1) return;

    final rawItems = data['items'];
    if (rawItems is! List) return;
    final matched = rawItems.cast<Map<String, dynamic>>().firstWhere(
      (i) => i['id'] == orderItemId,
      orElse: () => <String, dynamic>{},
    );
    if (matched.isEmpty) return;
    items[index] = OrderItems.fromJson(matched);

    final reason =
        data['cancellation_reason'] ?? items[index].cancellationReason;
    if (reason != null && reason.isNotEmpty) {
      current.orderDetail.cancellationReason = reason;
    }

    if (data['active_status'] != null) {
      current.orderDetail.activeStatus = data['active_status'];
    }
    if (data['is_cancellable'] != null) {
      current.orderDetail.isCancellable = data['is_cancellable'];
    } else if (items.every((i) => i.activeStatus == OrderStatus.cancelled)) {
      current.orderDetail.isCancellable = false;
    }
    emit(OrderDetailLoaded(current.orderDetail));
  }
}
