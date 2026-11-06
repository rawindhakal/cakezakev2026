import 'package:customer/core/constants/app_constants.dart';

/// `payment_method` values that aren't a selectable online gateway.
///
/// Gateways come from the payment-methods settings API and live in
/// [PaymentGatewayType]; these two are decided by the app/backend instead —
/// [wallet] is sent when the wallet balance covers the whole order (so no
/// gateway is involved at all), and [cod] settles at delivery. Order and
/// transaction screens read the API's raw `payment_method` back through
/// [fromRaw] to label and icon them.
enum OrderPaymentMethod {
  wallet(AppConstants.wallet),
  cod(AppConstants.cod);

  const OrderPaymentMethod(this.apiValue);

  /// Value sent to / received from backend as `payment_method`.
  final String apiValue;

  /// Resolves a raw API `payment_method` string. Returns null for gateway
  /// values (`razorpay`, `stripe`, …) and anything unrecognised.
  static OrderPaymentMethod? fromRaw(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    for (final method in OrderPaymentMethod.values) {
      if (method.apiValue.toLowerCase() == normalized) return method;
    }
    return null;
  }
}
