import 'dart:async';

import 'package:customer/core/services/notification_service.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/repositories/order_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds the order shown on [OrderTrackingScreen] and refetches it whenever
/// a foreground "order" push notification arrives for the same order id —
/// keeps status/timeline live while the screen is open, without the user
/// needing to leave and reopen it.
class OrderTrackingDetailCubit extends Cubit<OrderData> {
  final OrderRepository _repository;
  StreamSubscription<String>? _pushSubscription;

  OrderTrackingDetailCubit(
    OrderData initialOrder, {
    OrderRepository? repository,
  }) : _repository = repository ?? OrderRepository(),
       super(initialOrder) {
    final orderId = initialOrder.id?.toString();
    if (orderId != null && orderId.isNotEmpty) {
      // The order passed in (e.g. from the orders list) can be stale by the
      // time this screen opens/reopens — refresh once immediately so
      // `activeStatus` (and whether live tracking should be running) is
      // decided from current data, not a cached snapshot.
      _refresh(orderId);
      _pushSubscription = NotificationService.instance.orderPushStream
          .where((pushedId) => pushedId == orderId)
          .listen((_) => _refresh(orderId));
    }
  }

  Future<void> _refresh(String orderId) async {
    try {
      final updated = await _repository.getOrderDetail(orderId);
      emit(updated);
    } catch (_) {
      // Best-effort background refresh — keep showing the last known good
      // order rather than surfacing an error over an already-working screen.
    }
  }

  @override
  Future<void> close() {
    _pushSubscription?.cancel();
    return super.close();
  }
}
