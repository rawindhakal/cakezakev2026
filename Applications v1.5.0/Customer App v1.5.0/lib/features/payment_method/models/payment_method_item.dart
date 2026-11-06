import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';

import 'payment_methods_model.dart';

enum PaymentFlowType { webview, sdk, cod, manual }

enum PaymentGatewayType {
  phonepe(
    LanguageLabelKeys.phonepe,
    AssetsConstants.phonepeIcon,
    PaymentFlowType.webview,
    AppConstants.phonepe,
  ),
  midtrans(
    LanguageLabelKeys.midtrans,
    AssetsConstants.midtransIcon,
    PaymentFlowType.webview,
    AppConstants.midtrans,
  ),
  paystack(
    LanguageLabelKeys.paystack,
    AssetsConstants.paystackIcon,
    PaymentFlowType.sdk,
    AppConstants.paystack,
  ),
  stripe(
    LanguageLabelKeys.stripe,
    AssetsConstants.stripeIcon,
    PaymentFlowType.sdk,
    AppConstants.stripe,
  ),
  paypal(
    LanguageLabelKeys.paypal,
    AssetsConstants.paypalIcon,
    PaymentFlowType.webview,
    AppConstants.paypal,
  ),
  razorpay(
    LanguageLabelKeys.razorpay,
    AssetsConstants.razorpayIcon,
    PaymentFlowType.sdk,
    AppConstants.razorpay,
  ),
  cashfree(
    LanguageLabelKeys.cashfree,
    AssetsConstants.cashfreeIcon,
    PaymentFlowType.webview,
    AppConstants.cashfree,
  ),
  paytabs(
    LanguageLabelKeys.paytabs,
    AssetsConstants.paytabsIcon,
    PaymentFlowType.webview,
    AppConstants.paytabs,
  ),
  cod(
    LanguageLabelKeys.cashOnDelivery,
    AssetsConstants.codIcon,
    PaymentFlowType.cod,
    AppConstants.cod,
  ),
  // CakeZake accepts only COD plus these in-person / manually verified methods.
  payAtCounter(
    'Pay at counter',
    AssetsConstants.codIcon,
    PaymentFlowType.cod,
    'PayAtCounter',
  ),
  esewa(
    'eSewa',
    AssetsConstants.codIcon,
    PaymentFlowType.manual,
    'Esewa',
  ),
  bankTransfer(
    'Bank transfer',
    AssetsConstants.codIcon,
    PaymentFlowType.manual,
    'BankTransfer',
  ),
  qrPayment(
    'QR payment',
    AssetsConstants.codIcon,
    PaymentFlowType.manual,
    'QrPayment',
  ),
  dpo(
    LanguageLabelKeys.dpo,
    AssetsConstants.dpoIcon,
    PaymentFlowType.webview,
    AppConstants.dpo,
  ),
  payu(
    LanguageLabelKeys.payu,
    AssetsConstants.payuIcon,
    PaymentFlowType.webview,
    AppConstants.payu,
  );

  const PaymentGatewayType(
    this.label,
    this.iconPath,
    this.flowType,
    this.apiValue,
  );

  final String label;
  final String iconPath;
  final PaymentFlowType flowType;

  /// Value sent to backend as `payment_method`
  final String apiValue;
}

class PaymentMethodItem {
  const PaymentMethodItem(this.type);

  final PaymentGatewayType type;

  String get label => type.label;
  String get iconPath => type.iconPath;
  PaymentFlowType get flowType => type.flowType;
  String get apiValue => type.apiValue;

  static List<PaymentMethodItem> fromData(PaymentMethodsData data) {
    final map = <PaymentGatewayType, String?>{
      PaymentGatewayType.cod: data.codPaymentMethod,
      PaymentGatewayType.payAtCounter: data.counterPaymentMethod,
      PaymentGatewayType.esewa: data.esewaPaymentMethod,
      PaymentGatewayType.bankTransfer: data.bankPaymentMethod,
      PaymentGatewayType.qrPayment: data.qrPaymentMethod,
    };

    return map.entries
        .where((e) => e.value == '1')
        .map((e) => PaymentMethodItem(e.key))
        .toList();
  }
}
