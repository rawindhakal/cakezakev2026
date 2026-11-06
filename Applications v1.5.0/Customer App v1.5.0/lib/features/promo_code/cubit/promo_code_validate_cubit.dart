import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/features/promo_code/repositories/promo_code_repository.dart';

// ── States ───────────────────────────────────────────────────────────────────

sealed class PromoCodeValidateState {}

final class PromoCodeValidateInitial extends PromoCodeValidateState {}

final class PromoCodeValidateLoading extends PromoCodeValidateState {
  final String promoCode;
  PromoCodeValidateLoading(this.promoCode);
}

final class PromoCodeValidateSuccess extends PromoCodeValidateState {
  final PromoCodeData data;
  PromoCodeValidateSuccess(this.data);
}

final class PromoCodeValidateError extends PromoCodeValidateState {
  final String message;
  PromoCodeValidateError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class PromoCodeValidateCubit extends Cubit<PromoCodeValidateState>
    with ApiErrorGuard<PromoCodeValidateState> {
  final PromoCodeRepository _repository;

  PromoCodeValidateCubit({PromoCodeRepository? repository})
    : _repository = repository ?? PromoCodeRepository(),
      super(PromoCodeValidateInitial());

  Future<void> validate({
    required String promoCode,
    required String total,
    String? latitude,
    String? longitude,
    DeliveryType deliveryType = DeliveryType.delivery,
  }) async {
    emit(PromoCodeValidateLoading(promoCode));
    await guard(() async {
      final data = await _repository.validatePromoCode(
        promoCode: promoCode,
        total: total,
        latitude: latitude,
        longitude: longitude,
        deliveryType: deliveryType,
      );
      emit(PromoCodeValidateSuccess(data));
    }, onError: (msg) => emit(PromoCodeValidateError(msg)));
  }

  void reset() => emit(PromoCodeValidateInitial());
}
