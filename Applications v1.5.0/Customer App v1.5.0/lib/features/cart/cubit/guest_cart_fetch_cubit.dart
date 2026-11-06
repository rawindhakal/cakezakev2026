import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class GuestCartState {}

final class GuestCartInitial extends GuestCartState {}

final class GuestCartLoading extends GuestCartState {}

final class GuestCartLoaded extends GuestCartState {
  final Cart cart;
  GuestCartLoaded(this.cart);
}

final class GuestCartError extends GuestCartState {
  final String message;
  GuestCartError(this.message);
}

class GuestCartFetchCubit extends Cubit<GuestCartState> {
  final CartRepository _repository;

  GuestCartFetchCubit({CartRepository? repository})
    : _repository = repository ?? CartRepository(),
      super(GuestCartInitial());

  /// [silent] = true keeps the current loaded UI visible while refetching
  /// (no Loading state), so qty changes don't flicker the screen.
  Future<void> fetchGuestCart({
    required List<String> variantIds,
    required List<String> quantities,
    // Add-on module: per-item list used once the cart has add-on lines.
    List<Map<String, dynamic>> items = const [],
    bool silent = false,
    // Passed through untouched; omit to keep existing delivery-only behavior.
    DeliveryType? deliveryType,
  }) async {
    try {
      if (variantIds.isEmpty && items.isEmpty) {
        emit(GuestCartInitial());
        return;
      }
      if (!silent || state is! GuestCartLoaded) emit(GuestCartLoading());
      final result = await _repository.getGuestCart(
        variantIds: variantIds,
        quantities: quantities,
        items: items,
        deliveryType: deliveryType,
      );
      // Screen may have been popped while the request was in flight.
      if (isClosed) return;
      emit(GuestCartLoaded(result));
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(GuestCartError(e.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        GuestCartError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
