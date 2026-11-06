import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/services/analytics_service.dart';
import 'package:customer/core/services/crashlytics_service.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/checkout/repositories/checkout_repository.dart';
import 'package:customer/features/payment_method/models/enums/order_payment_method.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ───────────────────────────────────────────────────────────────────

sealed class PlaceOrderState {}

final class PlaceOrderInitial extends PlaceOrderState {}

final class PlaceOrderLoading extends PlaceOrderState {}

final class PlaceOrderSuccess extends PlaceOrderState {
  PlaceOrderSuccess({
    required this.orderId,
    required this.isCod,
    this.orderItemId = '',
  });
  final String orderId;
  final bool isCod;

  /// Ecommerce channel's item-level id, present alongside order_id in the
  /// place-order response for ecommerce orders.
  final String orderItemId;
}

final class PlaceOrderError extends PlaceOrderState {
  PlaceOrderError(this.message);
  final String message;
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class PlaceOrderCubit extends Cubit<PlaceOrderState> {
  PlaceOrderCubit({CheckoutRepository? repository})
    : _repository = repository ?? CheckoutRepository(),
      super(PlaceOrderInitial());

  final CheckoutRepository _repository;

  Future<void> placeOrder({
    // Required for delivery; may be omitted for pickup — see
    // CheckoutRepository.placeOrder.
    String? addressId,
    required String paymentMethod,
    String? promoCodeId,
    String? walletUsed,
    String? walletBalance,
    String? orderNote,
    Map<String, String>? prescriptions,
    // Null for pickup — omits the key from the request entirely.
    bool? billingSameAsShipping,
    String? billingName,
    String? billingMobile,
    String? billingAddress,
    String? billingCity,
    String? billingPincode,
    String? billingCountry,
    String? billingState,
    int? billingRegionId,
    String? buyerTaxNumber,
    String? buyerBusinessName,
    DeliveryType? deliveryType,
    String? latitude,
    String? longitude,
  }) async {
    emit(PlaceOrderLoading());
    try {
      final isCod =
          OrderPaymentMethod.fromRaw(paymentMethod) == OrderPaymentMethod.cod ||
          paymentMethod == 'PayAtCounter';

      final map = await _repository.placeOrder(
        addressId: addressId,
        paymentMethod: paymentMethod,
        promoCodeId: promoCodeId,
        walletUsed: walletUsed,
        walletBalance: walletBalance,
        orderNote: orderNote,
        prescriptions: prescriptions,
        billingSameAsShipping: billingSameAsShipping,
        billingName: billingName,
        billingMobile: billingMobile,
        billingAddress: billingAddress,
        billingCity: billingCity,
        billingPincode: billingPincode,
        billingCountry: billingCountry,
        billingState: billingState,
        billingRegionId: billingRegionId,
        buyerTaxNumber: buyerTaxNumber,
        buyerBusinessName: buyerBusinessName,
        deliveryType: deliveryType,
        latitude: latitude,
        longitude: longitude,
      );

      final responseStatus = map['status']?.toString() ?? '0';
      if (responseStatus != '1') {
        emit(
          PlaceOrderError(
            map['message']?.toString() ??
                LocalizationService.instance.translate(
                  LanguageLabelKeys.failedToPlaceOrder,
                ),
          ),
        );
        return;
      }
      final orderId = (map['order_id'] ?? map['data']?['order_id'] ?? '')
          .toString();
      final orderItemId =
          (map['order_item_id'] ?? map['data']?['order_item_id'] ?? '')
              .toString();
      AnalyticsService.instance.logEvent(
        AppConstants.eventPurchase,
        parameters: {
          AppConstants.paramTransactionId: orderId,
          AppConstants.paramPaymentType: paymentMethod,
        },
      );
      emit(
        PlaceOrderSuccess(
          orderId: orderId,
          isCod: isCod,
          orderItemId: orderItemId,
        ),
      );
    } on ApiException catch (e) {
      emit(PlaceOrderError(e.message));
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'placeOrder failed',
      );
      emit(
        PlaceOrderError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(PlaceOrderInitial());
}
