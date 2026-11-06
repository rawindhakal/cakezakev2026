import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/services/analytics_service.dart';
import 'package:customer/core/services/crashlytics_service.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class CartActionState {}

final class CartActionInitial extends CartActionState {}

final class CartActionLoading extends CartActionState {}

final class CartActionSuccess extends CartActionState {
  /// Full cart payload from add/remove response (null for clear).
  final Cart? cart;
  CartActionSuccess(this.cart);
}

final class CartActionError extends CartActionState {
  final String message;

  /// True when this error came from [CartActionCubit.removeFromCart].
  /// Some backends respond with a non-1 status when a remove call empties
  /// the cart — that's not a real failure, so the UI shouldn't toast it.
  final bool fromRemove;
  CartActionError(this.message, {this.fromRemove = false});
}

class CartActionCubit extends Cubit<CartActionState> {
  final CartRepository _repository;

  CartActionCubit({CartRepository? repository})
    : _repository = repository ?? CartRepository(),
      super(CartActionInitial());

  /// Debounced [CartButton] syncs register here while their timer is
  /// pending. [flushAllPending] drains them synchronously (in order) so a
  /// channel switch never lets a stale-channel request fire late.
  final List<Future<void> Function()> _pendingFlushers = [];

  void registerPendingFlush(Future<void> Function() flusher) {
    _pendingFlushers.add(flusher);
  }

  void unregisterPendingFlush(Future<void> Function() flusher) {
    _pendingFlushers.remove(flusher);
  }

  /// Call before switching quick/ecommerce channel so every in-flight debounce
  /// sends its request under the channel it was scheduled on, not whatever
  /// channel is active by the time its timer would have fired.
  Future<void> flushAllPending() async {
    final flushers = List<Future<void> Function()>.from(_pendingFlushers);
    _pendingFlushers.clear();
    for (final flush in flushers) {
      await flush();
    }
  }

  // Bumped on every addToCart/removeFromCart call. When a burst of taps on
  // different items fires overlapping requests, network responses can
  // resolve out of order — an earlier-started request's full-cart snapshot
  // arriving after a later one would stomp the more recent change (a
  // removed item reappearing). Only the response for the most-recently
  // STARTED request is applied, regardless of resolve order.
  int _generation = 0;

  /// Add-on module: [addons] carries an add-on line's chosen options.
  Future<void> addToCart({
    required String productId,
    required String productVariantId,
    required int qty,
    List<AddonSelection>? addons,
  }) async {
    final generation = ++_generation;
    try {
      emit(CartActionLoading());
      final cart = await _repository.addToCart(
        productId: productId,
        productVariantId: productVariantId,
        qty: qty,
        addons: addons,
      );
      AnalyticsService.instance.logEvent(
        AppConstants.eventAddToCart,
        parameters: {
          AppConstants.paramItemId: productId,
          AppConstants.paramQuantity: qty,
        },
      );
      if (generation != _generation) return;
      emit(CartActionSuccess(cart));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(CartActionError(e.message));
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'addToCart failed',
      );
      if (generation != _generation) return;
      emit(
        CartActionError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Add-on module: [addons] picks which line of the product to hit.
  Future<void> removeFromCart({
    required String productId,
    required String productVariantId,
    int qty = 0,
    List<AddonSelection>? addons,
  }) async {
    final generation = ++_generation;
    try {
      emit(CartActionLoading());
      final cart = await _repository.removeFromCart(
        productId: productId,
        productVariantId: productVariantId,
        qty: qty,
        addons: addons,
      );
      AnalyticsService.instance.logEvent(
        AppConstants.eventRemoveFromCart,
        parameters: {
          AppConstants.paramItemId: productId,
          AppConstants.paramQuantity: qty,
        },
      );
      if (generation != _generation) return;
      emit(CartActionSuccess(cart));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(CartActionError(e.message, fromRemove: true));
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'removeFromCart failed',
      );
      if (generation != _generation) return;
      emit(
        CartActionError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
          fromRemove: true,
        ),
      );
    }
  }

  Future<void> clearCart() async {
    try {
      emit(CartActionLoading());
      await _repository.clearCart();
      emit(CartActionSuccess(null));
    } on ApiException catch (e) {
      emit(CartActionError(e.message));
    } catch (_) {
      emit(
        CartActionError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(CartActionInitial());
}
