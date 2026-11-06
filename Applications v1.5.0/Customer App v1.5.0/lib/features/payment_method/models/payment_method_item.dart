import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';

import 'payment_methods_model.dart';

enum PaymentFlowType { webview, sdk, cod }

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
      PaymentGatewayType.phonepe: data.phonePePaymentMethod,
      PaymentGatewayType.midtrans: data.midtransPaymentMethod,
      PaymentGatewayType.paystack: data.paystackPaymentMethod,
      PaymentGatewayType.stripe: data.stripePaymentMethod,
      PaymentGatewayType.paypal: data.paypalPaymentMethod,
      PaymentGatewayType.razorpay: data.razorpayPaymentMethod,
      PaymentGatewayType.cashfree: data.cashfreePaymentMethod,
      PaymentGatewayType.paytabs: data.paytabsPaymentMethod,
      PaymentGatewayType.cod: data.codPaymentMethod,
      PaymentGatewayType.dpo: data.dpoPaymentMethod,
      PaymentGatewayType.payu: data.payuPaymentMethod,
    };

    return map.entries
        .where((e) => e.value == '1')
        .map((e) => PaymentMethodItem(e.key))
        .toList();
  }
}
