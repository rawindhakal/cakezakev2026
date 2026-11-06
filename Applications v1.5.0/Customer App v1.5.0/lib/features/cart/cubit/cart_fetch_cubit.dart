import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class CartFetchState {}

final class CartFetchInitial extends CartFetchState {}

final class CartFetchLoading extends CartFetchState {}

final class CartFetchLoaded extends CartFetchState {
  final Cart cart;
  CartFetchLoaded(this.cart);
}

final class CartFetchError extends CartFetchState {
  final String message;
  CartFetchError(this.message);
}

class CartFetchCubit extends Cubit<CartFetchState> {
  final CartRepository _repository;

  CartFetchCubit({CartRepository? repository})
    : _repository = repository ?? CartRepository(),
      super(CartFetchInitial());

  /// Update state directly from an already-fetched cart payload (e.g. the
  /// response of add/remove) — no Loading state, so the screen doesn't flicker.
  void setCart(Cart cart) => emit(CartFetchLoaded(cart));

  Future<void> fetchCart({
    String? latitude,
    String? longitude,
    String? addressId,
    // Passed through untouched; omit to keep existing delivery-only behavior.
    DeliveryType? deliveryType,
  }) async {
    try {
      emit(CartFetchLoading());
      final result = await _repository.getCart(
        latitude: latitude,
        longitude: longitude,
        addressId: addressId,
        deliveryType: deliveryType,
      );
      emit(CartFetchLoaded(result));
    } on ApiException catch (e) {
      emit(CartFetchError(e.message));
    } catch (_) {
      emit(
        CartFetchError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
