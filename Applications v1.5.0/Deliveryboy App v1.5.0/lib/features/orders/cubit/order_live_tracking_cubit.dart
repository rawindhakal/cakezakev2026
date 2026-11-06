import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef OrderLiveTrackingState = AsyncState<()>;
typedef OrderLiveTrackingInitial = AsyncInitial<()>;
typedef OrderStatusUpdating = AsyncLoading<()>;
typedef OrderLiveTrackingLoaded = AsyncLoaded<()>;
typedef OrderLiveTrackingError = AsyncError<()>;

/// Pushes the delivery boy's live latitude/longitude for an in-progress order.
class OrderLiveTrackingCubit extends BaseAsyncCubit<()> {
  final OrderRepository _repository;

  OrderLiveTrackingCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  String? _orderId;
  String? get orderId => _orderId;
  int? currentOrderStatus;

  /// The `OrderLiveTrackingCubit` backing whichever tracking screen is
  /// currently open, if any — at most one is on-screen at a time. Lets
  /// `NotificationService` know an order-status push matches the order
  /// already being tracked, so it can refresh it in place (mirrors
  /// `ChatCubit.active`).
  static OrderLiveTrackingCubit? active;

  /// Registers this cubit as tracking [orderId], starting from
  /// [initialStatus] — called once from `OrderTrackingScreen.initState`.
  void trackOrder(String orderId, int? initialStatus) {
    _orderId = orderId;
    currentOrderStatus = initialStatus;
    active = this;
  }

  void stopTracking() {
    if (identical(active, this)) active = null;
  }

  /// Sends the current [latitude]/[longitude] for [orderId] with its [orderStatus].
  Future<void> orderLiveTracking({
    required String orderId,
    required String orderStatus,
    required String latitude,
    required String longitude,
  }) => run(() async {
    await _repository.orderLiveTracking(
      orderId: orderId,
      orderStatus: orderStatus,
      latitude: latitude,
      longitude: longitude,
    );
    return ();
  });

  /// Re-fetches the order's status when a push notification for [_orderId]
  /// arrives while its tracking screen is open, so the screen can switch
  /// store↔customer tracking (and start/stop the live-location API) without
  /// the user having to leave and reopen the screen.
  Future<void> refreshFromNotification() => run(() async {
    final id = _orderId;
    if (id != null) {
      try {
        final detail = await _repository.getOrderById(id);
        currentOrderStatus = detail.data?.order?.activeStatus;
      } catch (_) {
        // Best-effort refresh — keep the last known status on failure.
      }
    }
    return ();
  });
}
