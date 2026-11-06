import 'dart:async';

import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/repositories/order_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class OrderLiveTrackingState {}

final class OrderLiveTrackingInitial extends OrderLiveTrackingState {}

final class OrderLiveTrackingLoading extends OrderLiveTrackingState {}

final class OrderLiveTrackingLoaded extends OrderLiveTrackingState {
  final LiveLocation location;
  OrderLiveTrackingLoaded(this.location);
}

final class OrderLiveTrackingError extends OrderLiveTrackingState {
  final String message;
  OrderLiveTrackingError(this.message);
}

/// Polls the delivery boy's live lat/lng every 15s while an order is out for delivery.
class OrderLiveTrackingCubit extends Cubit<OrderLiveTrackingState> {
  final OrderRepository _repository;
  Timer? _timer;

  OrderLiveTrackingCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(OrderLiveTrackingInitial());

  void startTracking(String orderId) {
    _timer?.cancel();
    _fetch(orderId);
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetch(orderId),
    );
  }

  /// Stops the 15s poll — called once the order leaves the out-for-delivery
  /// state (delivered/cancelled/etc.) so a stale rider position isn't kept
  /// alive after live tracking no longer applies.
  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    if (state is! OrderLiveTrackingInitial) emit(OrderLiveTrackingInitial());
  }

  Future<void> _fetch(String orderId) async {
    if (state is OrderLiveTrackingInitial) emit(OrderLiveTrackingLoading());
    try {
      final location = await _repository.getLiveLocation(orderId);
      emit(OrderLiveTrackingLoaded(location));
    } on ApiException catch (e) {
      emit(OrderLiveTrackingError(e.message));
    } catch (_) {
      emit(
        OrderLiveTrackingError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
