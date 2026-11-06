import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/products/models/serviceability_model.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ServiceabilityState {
  const ServiceabilityState();
}

final class ServiceabilityInitial extends ServiceabilityState {
  const ServiceabilityInitial();
}

final class ServiceabilityLoading extends ServiceabilityState {
  const ServiceabilityLoading();
}

final class ServiceabilityLoaded extends ServiceabilityState {
  final ServiceabilityModel result;
  const ServiceabilityLoaded(this.result);
}

final class ServiceabilityError extends ServiceabilityState {
  final String message;
  const ServiceabilityError(this.message);
}

class ServiceabilityCubit extends Cubit<ServiceabilityState>
    with ApiErrorGuard<ServiceabilityState> {
  final ProductRepository _repository;

  ServiceabilityCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(const ServiceabilityInitial());

  /// Last pincode checked, used to re-check when the variant changes.
  String? pincode;

  /// True when the buy button must be blocked: a check ran and the product
  /// can't be delivered to the pincode (courier_serviceable = false).
  bool get blocksPurchase {
    final s = state;
    return s is ServiceabilityLoaded && s.result.courierServiceable == false;
  }

  Future<void> check({
    required String pincode,
    required String productVariantId,
  }) async {
    this.pincode = pincode;
    // Only the latest request may emit; an older in-flight response
    // (previous variant/pincode) must not overwrite it.
    final requestId = ++_requestId;
    emit(const ServiceabilityLoading());
    await guard(() async {
      final result = await _repository.checkServiceability(
        pincode: pincode,
        productVariantId: productVariantId,
      );
      if (requestId == _requestId) emit(ServiceabilityLoaded(result));
    }, onError: (msg) {
      if (requestId == _requestId) emit(ServiceabilityError(msg));
    });
  }

  int _requestId = 0;

  void reset() {
    _requestId++;
    pincode = null;
    emit(const ServiceabilityInitial());
  }
}
