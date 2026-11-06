import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/models/payment_args.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

mixin RazorpayLauncherMixin<T extends StatefulWidget> on State<T> {
  /// Order/amount/currency for the in-flight payment attempt — provided by
  /// the host screen (payment methods list, or checkout paying directly).
  PaymentArgs get launcherArgs;

  late final Razorpay razorpay;

  void initRazorpay() {
    razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
  }

  void disposeRazorpay() => razorpay.clear();

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    context.read<PaymentCubit>().addTransaction(
      orderId: launcherArgs.orderId,
      orderItemId: launcherArgs.orderItemId,
      paymentType: PaymentGatewayType.razorpay.apiValue,
      txnId: response.paymentId ?? '',
      success: true,
      extra: launcherArgs.extra,
    );
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    context.read<PaymentCubit>().addTransaction(
      orderId: launcherArgs.orderId,
      orderItemId: launcherArgs.orderItemId,
      paymentType: PaymentGatewayType.razorpay.apiValue,
      txnId: response.error?['metadata']?['payment_id']?.toString() ?? '',
      success: false,
      extra: launcherArgs.extra,
    );
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {}

  void launchRazorpay(
    PaymentSdkReady sdkState,
    PaymentMethodsData? methodsData,
  ) {
    final key = methodsData?.razorpayKey ?? '';
    if (key.isEmpty) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.razorpayKeyNotConfigured),
        type: SnackBarType.error,
      );
      context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
      context.read<PaymentCubit>().reset();
      return;
    }

    final options = <String, dynamic>{
      'key': key,
      'amount': (launcherArgs.amount * 100).toInt(),
      'name': launcherArgs.userName ?? '',
      'description': launcherArgs.description ?? '',
      'prefill': {
        'contact': launcherArgs.userPhone ?? '',
        'email': launcherArgs.userEmail ?? '',
      },
      'external': {'wallets': []},
    };
    try {
      razorpay.open(options);
    } catch (e) {
      AppSnackBar.show(
        context: context,
        message: e.toString(),
        type: SnackBarType.error,
      );
    }
  }
}
