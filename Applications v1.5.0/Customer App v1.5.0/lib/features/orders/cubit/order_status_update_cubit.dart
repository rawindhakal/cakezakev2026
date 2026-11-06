import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/orders/repositories/order_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class OrderStatusUpdateState {}

final class OrderStatusUpdateInitial extends OrderStatusUpdateState {}

final class OrderStatusUpdating extends OrderStatusUpdateState {}

final class OrderStatusUpdateLoaded extends OrderStatusUpdateState {
  final Map<String, dynamic>? data;
  final String? orderItemId;
  OrderStatusUpdateLoaded({this.data, this.orderItemId});
}

final class OrderStatusUpdateError extends OrderStatusUpdateState {
  final String message;
  OrderStatusUpdateError(this.message);
}

class OrderStatusUpdateCubit extends Cubit<OrderStatusUpdateState>
    with ApiErrorGuard<OrderStatusUpdateState> {
  final OrderRepository _repository;

  OrderStatusUpdateCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(OrderStatusUpdateInitial());

  /// Returns the updated item from the response (or null on failure) so
  /// callers can patch local state without a refetch, while still emitting
  /// states for screens that listen for a generic success/error reaction.
  Future<Map<String, dynamic>?> updateStatus({
    required String orderId,
    required String status,
    String? orderItemId,
    String? from,
    String? reason,
    String? addressId,
  }) async {
    emit(OrderStatusUpdating());
    Map<String, dynamic>? result;
    await guard(() async {
      final data = await _repository.updateOrderStatus(
        orderId: orderId,
        status: status,
        orderItemId: orderItemId,
        from: from,
        reason: reason,
        addressId: addressId,
      );
      result = data;
      emit(OrderStatusUpdateLoaded(data: data, orderItemId: orderItemId));
    }, onError: (msg) => emit(OrderStatusUpdateError(msg)));
    return result;
  }
}
