class PaymentMethods {
  PaymentMethods({
    required this.status,
    required this.message,
    required this.total,
    required this.data,
  });

  late final int status;
  late final String message;
  late final int total;
  late final PaymentMethodsData data;

  PaymentMethods.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toInt() ?? 0;
    message = json['message']?.toString() ?? "";
    total = json['total']?.toInt() ?? 0;
    // An error response omits `data` entirely; every field defaults to '' so
    // an empty map keeps `data` non-nullable without crashing callers.
    data = PaymentMethodsData.fromJson(
      json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    final itemData = <String, dynamic>{};
    itemData['status'] = status;
    itemData['message'] = message;
    itemData['total'] = total;
    itemData['data'] = data.toJson();
    return itemData;
  }
}

class PaymentMethodsData {
  String? stripePublishableKey;
  String? paymentMethodSettings;
  String? codPaymentMethod;
  String? codMode;
  String? paypalPaymentMethod;
  String? razorpayPaymentMethod;
  String? razorpayKey;
  String? paystackPaymentMethod;
  String? paystackPublicKey;
  String? paystackCurrencyCode;
  String? midtransPaymentMethod;
  String? stripePaymentMethod;
  String? stripeCurrencyCode;
  String? stripeMode;
  String? phonePePaymentMethod;
  String? phonepayMode;
  String? cashfreePaymentMethod;
  String? cashfreeMode;
  String? paytabsPaymentMethod;
  String? paytabsMode;
  String? dpoPaymentMethod;
  String? dpoMode;
  String? dpoCurrencyCode;
  String? payuPaymentMethod;
  String? payuMerchantKey;
  String? payuMode;
  String? currency;
  String? currencyCode;
  int? decimalPoint;

  PaymentMethodsData({
    this.stripePublishableKey,
    this.paymentMethodSettings,
    this.codPaymentMethod,
    this.codMode,
    this.paypalPaymentMethod,
    this.razorpayPaymentMethod,
    this.razorpayKey,
    this.paystackPaymentMethod,
    this.paystackPublicKey,
    this.paystackCurrencyCode,
    this.midtransPaymentMethod,
    this.stripePaymentMethod,
    this.stripeCurrencyCode,
    this.stripeMode,
    this.phonePePaymentMethod,
    this.phonepayMode,
    this.cashfreePaymentMethod,
    this.cashfreeMode,
    this.paytabsPaymentMethod,
    this.paytabsMode,
    this.dpoPaymentMethod,
    this.dpoMode,
    this.dpoCurrencyCode,
    this.payuPaymentMethod,
    this.payuMerchantKey,
    this.payuMode,
  });

  PaymentMethodsData.fromJson(Map<String, dynamic> json) {
    stripePublishableKey = json['stripe_publishable_key']?.toString() ?? '';
    paymentMethodSettings = json['payment_method_settings']?.toString() ?? '';
    codPaymentMethod = json['cod_payment_method']?.toString() ?? '';
    codMode = json['cod_mode']?.toString() ?? '';
    paypalPaymentMethod = json['paypal_payment_method']?.toString() ?? '';
    razorpayPaymentMethod = json['razorpay_payment_method']?.toString() ?? '';
    razorpayKey = json['razorpay_key']?.toString() ?? '';
    paystackPaymentMethod = json['paystack_payment_method']?.toString() ?? '';
    paystackPublicKey = json['paystack_public_key']?.toString() ?? '';
    paystackCurrencyCode = json['paystack_currency_code']?.toString() ?? '';
    midtransPaymentMethod = json['midtrans_payment_method']?.toString() ?? '';
    stripePaymentMethod = json['stripe_payment_method']?.toString() ?? '';
    stripeCurrencyCode = json['stripe_currency_code']?.toString() ?? '';
    stripeMode = json['stripe_mode']?.toString() ?? '';
    phonePePaymentMethod = json['phonepay_payment_method']?.toString() ?? '';
    phonepayMode = json['phonepay_mode']?.toString() ?? '';
    cashfreePaymentMethod = json['cashfree_payment_method']?.toString() ?? '';
    cashfreeMode = json['cashfree_mode']?.toString() ?? '';
    paytabsPaymentMethod = json['paytabs_payment_method']?.toString() ?? '';
    paytabsMode = json['paytabs_mode']?.toString() ?? '';
    dpoPaymentMethod = json['dpo_payment_method']?.toString() ?? "0";
    dpoMode = json['dpo_mode']?.toString() ?? "";
    dpoCurrencyCode = json['dpo_currency_code']?.toString() ?? "";
    payuPaymentMethod = json['payu_payment_method']?.toString() ?? '';
    payuMerchantKey = json['payu_merchant_key']?.toString() ?? '';
    payuMode = json['payu_mode']?.toString() ?? '';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stripe_publishable_key'] = stripePublishableKey;
    data['payment_method_settings'] = paymentMethodSettings;
    data['cod_payment_method'] = codPaymentMethod;
    data['cod_mode'] = codMode;
    data['paypal_payment_method'] = paypalPaymentMethod;
    data['razorpay_payment_method'] = razorpayPaymentMethod;
    data['razorpay_key'] = razorpayKey;
    data['paystack_payment_method'] = paystackPaymentMethod;
    data['paystack_public_key'] = paystackPublicKey;
    data['paystack_currency_code'] = paystackCurrencyCode;
    data['midtrans_payment_method'] = midtransPaymentMethod;
    data['stripe_payment_method'] = stripePaymentMethod;
    data['stripe_currency_code'] = stripeCurrencyCode;
    data['stripe_mode'] = stripeMode;
    data['phonepay_payment_method'] = phonePePaymentMethod;
    data['phonepay_mode'] = phonepayMode;
    data['cashfree_payment_method'] = cashfreePaymentMethod;
    data['cashfree_mode'] = cashfreeMode;
    data['paytabs_payment_method'] = paytabsPaymentMethod;
    data['paytabs_mode'] = paytabsMode;
    data['dpo_payment_method'] = dpoPaymentMethod;
    data['dpo_mode'] = dpoMode;
    data['dpo_currency_code'] = dpoCurrencyCode;
    data['payu_payment_method'] = payuPaymentMethod;
    data['payu_merchant_key'] = payuMerchantKey;
    data['payu_mode'] = payuMode;
    return data;
  }
}
