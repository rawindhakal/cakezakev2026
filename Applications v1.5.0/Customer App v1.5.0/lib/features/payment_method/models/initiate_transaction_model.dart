import 'payment_form_payload.dart';

class InitiateTransactionResponse {
  const InitiateTransactionResponse({
    required this.status,
    required this.message,
    this.data,
  });

  final String status;
  final String message;
  final InitiateTransactionData? data;

  factory InitiateTransactionResponse.fromJson(Map<String, dynamic> json) {
    return InitiateTransactionResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? InitiateTransactionData.fromJson(
              json['data'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class InitiateTransactionData {
  const InitiateTransactionData({
    this.paymentUrl,
    this.orderId,
    this.transactionId,
    this.clientSecret,
    this.razorpayOrderId,
    this.merchantOrderId,
    this.token,
    this.formPayload,
  });

  final String? paymentUrl;
  final String? orderId;
  final String? transactionId;
  final String? clientSecret; // Stripe
  final String? razorpayOrderId; // Razorpay
  final String? merchantOrderId; // PhonePe status check
  final String? token; // PhonePe status check
  final PaymentFormPayload? formPayload; // PayU

  factory InitiateTransactionData.fromJson(Map<String, dynamic> json) {
    return InitiateTransactionData(
      // Each gateway uses a different key for the redirect URL
      paymentUrl:
          json['payment_url']?.toString() ??
          json['url']?.toString() ??
          json['redirect_url']?.toString() ??
          json['redirectUrl']?.toString() ?? // PhonePe, Cashfree, DPO, Paytabs
          json['snapUrl']?.toString() ?? // Midtrans
          json['paypal_redirect_url']?.toString(), // PayPal
      orderId: json['order_id']?.toString(),
      transactionId:
          json['transaction_id']?.toString() ?? json['txn_id']?.toString(),
      clientSecret: json['client_secret']?.toString(),
      razorpayOrderId: json['razorpay_order_id']?.toString(),
      merchantOrderId: json['merchantOrderId']?.toString(), // PhonePe
      token: json['token']?.toString(), // PhonePe
      formPayload: PaymentFormPayload.fromInitiateData(json),
    );
  }
}
