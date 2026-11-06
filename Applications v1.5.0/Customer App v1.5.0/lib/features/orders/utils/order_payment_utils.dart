import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/payment_method/models/enums/order_payment_method.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/widgets.dart';

/// Shared payment-mode helpers for order detail & tracking screens.
///
/// Wallet amount and the remaining payable amount always come from separate
/// API fields (wallet used vs. final_total) — these helpers never add the
/// two together, they only label how the remaining, non-wallet portion (if
/// any) was paid: COD, an online gateway, or nothing (wallet paid it all).
class OrderPaymentInfo {
  final bool hasWallet;
  final bool isFullyPaidByWallet;
  final bool isCod;
  final String methodLabel;

  /// True when both wallet and a remaining method (COD/gateway) paid part
  /// of the order — only then do the itemized wallet/remaining rows show
  /// separately below the Total row.
  final bool isCombined;

  /// Label for the Total row: "Paid via Wallet" when wallet paid it all,
  /// plain "Total" when wallet + a gateway/COD split the bill (the split
  /// itself is itemized in the rows below), else the plain "Total".
  final String totalRowLabel;

  /// Amount to show next to [totalRowLabel]: the wallet amount when wallet
  /// paid it all (since `final_total` is 0 and would look wrong), the sum
  /// of wallet + remaining when both were used, otherwise `final_total` as
  /// usual.
  final double totalRowAmount;

  /// True whenever wallet was involved (fully or partially) — callers use
  /// this to success-color the Total row instead of the neutral default.
  final bool totalRowIsWalletHighlighted;

  /// Label for the itemized remaining-amount row when [isCombined]:
  /// "Paid via `gateway/COD`". Empty when not combined.
  final String remainingRowLabel;

  /// Single-row variant for cards that show only one total line (no
  /// separate "Wallet Used" row above it, unlike the order-detail screens):
  /// "Paid via Wallet" when wallet paid it all, "Paid via Wallet+`gateway`"
  /// when wallet + a gateway/COD split the bill, else plain "Total". The
  /// amount is the *combined* wallet + remaining amount, since there's no
  /// separate row to show the wallet portion.
  final String combinedTotalRowLabel;
  final double combinedTotalRowAmount;

  const OrderPaymentInfo({
    required this.hasWallet,
    required this.isFullyPaidByWallet,
    required this.isCod,
    required this.methodLabel,
    required this.isCombined,
    required this.totalRowLabel,
    required this.totalRowAmount,
    required this.totalRowIsWalletHighlighted,
    required this.remainingRowLabel,
    required this.combinedTotalRowLabel,
    required this.combinedTotalRowAmount,
  });
}

/// Translates raw `payment_method` values from the API ('wallet', 'COD',
/// gateway names like 'razorpay'/'stripe') into a display label.
String formatOrderPaymentMethod(BuildContext context, String raw) {
  return switch (OrderPaymentMethod.fromRaw(raw)) {
    OrderPaymentMethod.wallet => context.translate(LanguageLabelKeys.wallet),
    OrderPaymentMethod.cod => context.translate(
      LanguageLabelKeys.cashOnDelivery,
    ),
    // Gateway names (razorpay, stripe, …) are shown as the API sent them.
    null => raw,
  };
}

/// Builds the combined wallet + payment-method picture for an order.
///
/// [walletUsed] is the wallet amount deducted for this order (`paid_wallet`
/// for quick orders, `wallet_balance` for ecommerce orders — callers pass
/// whichever field applies). [finalTotal] is the amount still payable
/// after the wallet deduction. [rawPaymentMethod] is the API's
/// `payment_method` string.
OrderPaymentInfo resolveOrderPaymentInfo({
  required BuildContext context,
  required double? walletUsed,
  required double? finalTotal,
  required String? rawPaymentMethod,
  bool isDelivered = false,
}) {
  final hasWallet = walletUsed != null && walletUsed != 0;
  final isFullyPaidByWallet = hasWallet && (finalTotal ?? 0) == 0;
  final raw = rawPaymentMethod ?? '';
  final isCod = OrderPaymentMethod.fromRaw(raw) == OrderPaymentMethod.cod;
  final methodLabel = raw.isEmpty ? '' : formatOrderPaymentMethod(context, raw);
  // COD money isn't actually collected until delivery — "Paid via COD"
  // would be a false claim beforehand, so use "Pay via" (future tense)
  // until the order is delivered. Other methods (wallet, gateways) are
  // charged upfront, so "Paid via" is always correct for them.
  final paidPrefixKey = (isCod && !isDelivered)
      ? LanguageLabelKeys.payVia
      : LanguageLabelKeys.paidVia;

  final isCombined = hasWallet && (finalTotal ?? 0) > 0;

  final String totalRowLabel;
  if (isFullyPaidByWallet) {
    totalRowLabel = context.translate(LanguageLabelKeys.paidFullyByWallet);
  } else {
    totalRowLabel = context.translate(LanguageLabelKeys.total);
  }

  final remainingRowLabel = isCombined && methodLabel.isNotEmpty
      ? '${context.translate(paidPrefixKey)} $methodLabel'
      : '';

  final String combinedTotalRowLabel;
  if (isFullyPaidByWallet) {
    combinedTotalRowLabel = context.translate(
      LanguageLabelKeys.paidFullyByWallet,
    );
  } else if (hasWallet) {
    final methodPart = methodLabel.isNotEmpty ? '+$methodLabel' : '';
    combinedTotalRowLabel =
        '${context.translate(paidPrefixKey)} '
        '${context.translate(LanguageLabelKeys.wallet)}$methodPart';
  } else {
    combinedTotalRowLabel = context.translate(LanguageLabelKeys.total);
  }
  final combinedTotalRowAmount = isFullyPaidByWallet
      ? walletUsed
      : hasWallet
      ? walletUsed + (finalTotal ?? 0)
      : (finalTotal ?? 0);

  final totalRowAmount = isFullyPaidByWallet
      ? walletUsed
      : isCombined
      ? walletUsed + (finalTotal ?? 0)
      : (finalTotal ?? 0);

  return OrderPaymentInfo(
    hasWallet: hasWallet,
    isFullyPaidByWallet: isFullyPaidByWallet,
    isCod: isCod,
    methodLabel: methodLabel,
    isCombined: isCombined,
    totalRowLabel: totalRowLabel,
    totalRowAmount: totalRowAmount,
    totalRowIsWalletHighlighted: hasWallet,
    remainingRowLabel: remainingRowLabel,
    combinedTotalRowLabel: combinedTotalRowLabel,
    combinedTotalRowAmount: combinedTotalRowAmount,
  );
}
