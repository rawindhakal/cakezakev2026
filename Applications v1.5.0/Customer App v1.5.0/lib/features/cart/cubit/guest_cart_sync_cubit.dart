import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class GuestCartSyncState {}

final class GuestCartSyncInitial extends GuestCartSyncState {}

final class GuestCartSyncLoading extends GuestCartSyncState {}

final class GuestCartSyncSuccess extends GuestCartSyncState {
  final String message;
  GuestCartSyncSuccess(this.message);
}

final class GuestCartSyncError extends GuestCartSyncState {
  final String message;

  /// True when the server answered and refused a line (`status: 0`), as
  /// opposed to a network/transport failure. Bulk-add stops at the first
  /// refused line with the earlier lines already in the cart.
  final bool refused;
  GuestCartSyncError(this.message, {this.refused = false});
}

class GuestCartSyncCubit extends Cubit<GuestCartSyncState> {
  final CartRepository _repository;

  GuestCartSyncCubit({CartRepository? repository})
    : _repository = repository ?? CartRepository(),
      super(GuestCartSyncInitial());

  /// Bulk-adds variant/qty pairs to the cart in one request. Used both for
  /// merging the local guest cart on login and for re-adding order items
  /// (e.g. reorder) — the backend resolves the cart by device/session, so
  /// the same call works whether or not the user is logged in.
  ///
  /// Add-on module: lines carrying addons travel with their answers in the
  /// same request (see [CartRepository.bulkAddToCart]).
  Future<void> bulkAddItems({
    List<BulkCartItem> quickItems = const [],
    List<BulkCartItem> ecommerceItems = const [],
  }) async {
    if (quickItems.isEmpty && ecommerceItems.isEmpty) {
      emit(GuestCartSyncSuccess(''));
      return;
    }
    try {
      emit(GuestCartSyncLoading());
      final message = await _repository.bulkAddToCart(
        quickItems: quickItems,
        ecommerceItems: ecommerceItems,
      );
      emit(GuestCartSyncSuccess(message));
    } on ApiException catch (e) {
      emit(GuestCartSyncError(e.message, refused: e.responseData != null));
    } catch (_) {
      emit(
        GuestCartSyncError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(GuestCartSyncInitial());
}
