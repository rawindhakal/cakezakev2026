import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/features/promo_code/repositories/promo_code_repository.dart';

// ── States ───────────────────────────────────────────────────────────────────

sealed class PromoCodeState {}

final class PromoCodeInitial extends PromoCodeState {}

final class PromoCodeLoading extends PromoCodeState {}

final class PromoCodeLoaded extends PromoCodeState {
  final List<PromoCodeData> items;
  PromoCodeLoaded(this.items);
}

final class PromoCodeError extends PromoCodeState {
  final String message;
  PromoCodeError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class PromoCodeCubit extends Cubit<PromoCodeState>
    with ApiErrorGuard<PromoCodeState> {
  final PromoCodeRepository _repository;

  PromoCodeCubit({PromoCodeRepository? repository})
    : _repository = repository ?? PromoCodeRepository(),
      super(PromoCodeInitial());

  Future<void> load({
    required String amount,
    String? latitude,
    String? longitude,
    DeliveryType deliveryType = DeliveryType.delivery,
  }) async {
    emit(PromoCodeLoading());
    await guard(() async {
      final result = await _repository.getPromoCodes(
        amount: amount,
        latitude: latitude,
        longitude: longitude,
        deliveryType: deliveryType,
      );
      emit(PromoCodeLoaded(result.data));
    }, onError: (msg) => emit(PromoCodeError(msg)));
  }
}
