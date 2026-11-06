import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/email_input_sheet.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/models/payment_args.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_paystack/flutter_paystack.dart';

mixin PaystackLauncherMixin<T extends StatefulWidget> on State<T> {
  /// Order/amount/currency for the in-flight payment attempt — provided by
  /// the host screen (payment methods list, or checkout paying directly).
  PaymentArgs get launcherArgs;

  Future<void> launchPaystack(
    PaymentSdkReady sdkState,
    PaymentMethodsData? methodsData,
  ) async {
    final publicKey = (methodsData?.paystackPublicKey ?? '').trim();
    if (kDebugMode) {
      debugPrint(
        '[Paystack] methodsData=${methodsData == null ? "null" : "loaded"} '
        'rawKey="${methodsData?.paystackPublicKey}" publicKey="$publicKey"',
      );
    }
    if (publicKey.isEmpty || !publicKey.startsWith('pk_')) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.paystackKeyNotConfigured),
        type: SnackBarType.error,
      );
      context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
      context.read<PaymentCubit>().reset();
      return;
    }

    var email = launcherArgs.userEmail ?? '';
    if (email.isEmpty) {
      if (!mounted) return;
      final enteredEmail = await showEmailInputSheet(context);
      if (!mounted) return;
      if (enteredEmail == null || enteredEmail.isEmpty) {
        context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
        context.read<PaymentCubit>().reset();
        return;
      }
      email = enteredEmail;
    }

    try {
      // Fresh plugin each launch — initialize() skips re-init if already
      // initialized, which would keep a stale key on a shared instance.
      final plugin = PaystackPlugin();
      await plugin.initialize(publicKey: publicKey);

      final ref = DateTime.now().millisecondsSinceEpoch.toString();

      // Paystack needs ISO currency code (NGN/GHS/ZAR/USD/KES), not a symbol.
      // launcherArgs.currency is a display symbol — never use it here.
      final currency = (methodsData?.paystackCurrencyCode ?? '')
          .trim()
          .toUpperCase();

      final charge = Charge()
        ..reference = ref
        ..amount = (launcherArgs.amount * 100).toInt()
        ..email = email
        ..currency = currency.isEmpty ? 'NGN' : currency;

      if (!mounted) return;
      final response = await plugin.checkout(
        context,
        charge: charge,
        method: CheckoutMethod.card,
        fullscreen: false,
      );

      if (!mounted) return;
      if (response.status) {
        context.read<PaymentCubit>().addTransaction(
          orderId: launcherArgs.orderId,
          orderItemId: launcherArgs.orderItemId,
          paymentType: PaymentGatewayType.paystack.apiValue,
          txnId: response.reference ?? ref,
          success: true,
          extra: launcherArgs.extra,
        );
      } else {
        AppSnackBar.show(
          context: context,
          message: context.translate(
            LanguageLabelKeys.paystackPaymentNotCompleted,
          ),
          type: SnackBarType.error,
        );
        context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
        context.read<PaymentCubit>().reset();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context: context,
        message: e.toString(),
        type: SnackBarType.error,
      );
      context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
      context.read<PaymentCubit>().reset();
    }
  }
}
