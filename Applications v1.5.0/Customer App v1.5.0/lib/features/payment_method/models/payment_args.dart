import 'package:customer/features/cart/models/delivery_type.dart';

/// Arguments needed to run a payment gateway attempt (order checkout or
/// wallet top-up). Shared by [PaymentMethodsScreen] (wallet top-up / manual
/// pick) and [CheckoutScreen] (method already picked on checkout).
class PaymentArgs {
  const PaymentArgs({
    required this.orderId,
    this.orderItemId = '',
    required this.amount,
    required this.currency,
    this.userEmail,
    this.userName,
    this.userPhone,
    this.description,
    this.isWalletTopUp = false,
    this.extra,
    this.deliveryType = DeliveryType.delivery,
  });

  final String orderId;

  /// Ecommerce channel's item-level id, carried through to order success.
  final String orderItemId;

  /// Carried through to order success — routes quick-channel "Track My
  /// Order" to order-detail (pickup) instead of order-tracking (delivery).
  final DeliveryType deliveryType;
  final double amount;
  final String currency;
  final String? userEmail;
  final String? userName;
  final String? userPhone;
  final String? description;

  /// True when this payment adds money to wallet (top-up).
  /// Success pops back with result=true instead of jumping to main.
  final bool isWalletTopUp;

  /// Extra params forwarded to initiate_transaction API.
  final Map<String, dynamic>? extra;
}
