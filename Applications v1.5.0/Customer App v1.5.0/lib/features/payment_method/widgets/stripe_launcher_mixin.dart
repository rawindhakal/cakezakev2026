import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/models/payment_args.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

mixin StripeLauncherMixin<T extends StatefulWidget> on State<T> {
  /// Order/amount/currency for the in-flight payment attempt — provided by
  /// the host screen (payment methods list, or checkout paying directly).
  PaymentArgs get launcherArgs;

  Future<void> launchStripe(
    PaymentSdkReady sdkState,
    PaymentMethodsData? methodsData,
  ) async {
    final publishableKey = methodsData?.stripePublishableKey ?? '';
    final currency = (methodsData?.stripeCurrencyCode ?? launcherArgs.currency)
        .toLowerCase();
    final amountInCents = (launcherArgs.amount * 100).toInt();
    final clientSecret = sdkState.clientSecret;
    final paymentIntentId = sdkState.transactionId;

    if (publishableKey.isEmpty ||
        clientSecret == null ||
        clientSecret.isEmpty) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.stripeKeysNotConfigured),
        type: SnackBarType.error,
      );
      context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
      context.read<PaymentCubit>().reset();
      return;
    }

    // Set publishable key — do NOT call applySettings() as it triggers
    // FlutterFragmentActivity check and can fail mid-flow.
    Stripe.publishableKey = publishableKey;

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          intentConfiguration: IntentConfiguration(
            mode: IntentMode.paymentMode(
              currencyCode: currency.toUpperCase(),
              amount: amountInCents,
            ),
          ),
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: AppConfig.appName,
          style: ThemeMode.system,
        ),
      );

      if (!mounted) return;
      await Stripe.instance.presentPaymentSheet();

      if (!mounted) return;
      context.read<PaymentCubit>().addTransaction(
        orderId: launcherArgs.orderId,
        orderItemId: launcherArgs.orderItemId,
        paymentType: PaymentGatewayType.stripe.apiValue,
        txnId: paymentIntentId ?? '',
        success: true,
        extra: launcherArgs.extra,
        callApi: false,
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      if (e.error.code == FailureCode.Canceled) {
        context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
        context.read<PaymentCubit>().reset();
        return;
      }
      final msg =
          e.error.localizedMessage ??
          e.error.message ??
          context.translate(LanguageLabelKeys.stripePaymentFailed);
      context.read<PaymentCubit>().addTransaction(
        orderId: launcherArgs.orderId,
        orderItemId: launcherArgs.orderItemId,
        paymentType: PaymentGatewayType.stripe.apiValue,
        txnId: paymentIntentId ?? '',
        success: false,
        extra: launcherArgs.extra,
      );
      AppSnackBar.show(
        context: context,
        message: msg,
        type: SnackBarType.error,
      );
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
