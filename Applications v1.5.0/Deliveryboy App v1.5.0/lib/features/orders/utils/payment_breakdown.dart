import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/widgets.dart';

/// Shared payment-breakdown logic for Quick, E-commerce, and Return orders.
///
/// All three order models expose the wallet amount already deducted from
/// the order total as `walletBalance`, and the remaining amount owed via
/// [remainingAmount] (`final_total`). When both wallet and a remaining
/// method are involved, each gets its own itemized row (same style) and
/// the Total row below is a plain sum — no single row tries to name both
/// methods at once. When only one method is involved, that row alone
/// carries the label and doubles as the Total.
class PaymentBreakdown {
  final double wallet;
  final double remaining;
  final bool isCod;
  final bool isDelivered;
  final String? rawMethod;
  final double refundAmount;

  const PaymentBreakdown({
    required this.wallet,
    required this.remaining,
    required this.isCod,
    this.isDelivered = false,
    this.rawMethod,
    this.refundAmount = 0,
  });

  factory PaymentBreakdown.compute({
    double? walletAmount,
    double? remainingAmount,
    String? paymentMethod,
    bool isDelivered = false,
    double? refundAmount,
  }) {
    return PaymentBreakdown(
      wallet: (walletAmount ?? 0) > 0 ? walletAmount! : 0,
      remaining: (remainingAmount ?? 0) > 0 ? remainingAmount! : 0,
      isCod: (paymentMethod ?? '').trim().toLowerCase() == 'cod',
      isDelivered: isDelivered,
      rawMethod: paymentMethod,
      refundAmount: (refundAmount ?? 0) > 0 ? refundAmount! : 0,
    );
  }

  bool get hasWallet => wallet > 0;
  bool get hasRemaining => remaining > 0;
  bool get isFullyPaidByWallet => hasWallet && !hasRemaining;

  /// True when both wallet and a remaining method paid part of the order —
  /// only then do the itemized Wallet/COD/Online rows show separately.
  bool get isCombined => hasWallet && hasRemaining;

  /// Cash the rider must physically collect from the customer — false once
  /// [isDelivered] (already collected) or once a refund has been issued
  /// (nothing left to collect).
  double get collectAmount =>
      (isCod && hasRemaining && !isDelivered && refundAmount <= 0)
      ? remaining
      : 0;
  bool get mustCollectCash => collectAmount > 0;

  /// The non-wallet method name: raw `payment_method` value (e.g. "Razorpay",
  /// "UPI") when present, falling back to the generic "Online"/"COD" label.
  String methodName(BuildContext context) {
    if (isCod) return context.translate(LanguageLabelKeys.cod);
    final raw = rawMethod?.trim() ?? '';
    return raw.isNotEmpty ? raw : context.translate(LanguageLabelKeys.online);
  }

  /// Label for the wallet's own row: "Paid via Wallet".
  String walletLabel(BuildContext context) =>
      '${context.translate(LanguageLabelKeys.paidVia)} ${context.translate(LanguageLabelKeys.wallet)}';

  /// Label for the remaining, non-wallet amount's row: "Pay via COD" before
  /// delivery, "Paid via COD" after — the actionable "Collect from
  /// Customer" wording lives only in the callout below, so this row never
  /// repeats the exact same text.
  String remainingLabel(BuildContext context) {
    final prefixKey = (isCod && !isDelivered)
        ? LanguageLabelKeys.payVia
        : LanguageLabelKeys.paidVia;
    return '${context.translate(prefixKey)} ${methodName(context)}';
  }

  /// Label for the Total row. Plain "Total" when both wallet and remaining
  /// rows are itemized above it; otherwise it's the only row, so it carries
  /// the full label itself.
  String totalLabel(BuildContext context) {
    if (isCombined) return context.translate(LanguageLabelKeys.total);
    if (isFullyPaidByWallet) {
      return context.translate(LanguageLabelKeys.paidFullyByWallet);
    }
    if (hasRemaining) return remainingLabel(context);
    return context.translate(LanguageLabelKeys.total);
  }

  /// Sum of whatever was actually paid/owed — equals the itemized rows
  /// above it when [isCombined], or the single amount otherwise.
  double get totalAmount => wallet + remaining;

  /// Single-row variant for listing cards that show only one total line (no
  /// separate itemized rows, unlike the detail screens): the label names
  /// both the wallet and the remaining method when combined ("Paid via
  /// Wallet+Razorpay" / "Wallet, collect ₹X from customer"), amount is the
  /// full order value (wallet + remaining).
  String combinedTotalLabel(BuildContext context) {
    if (isFullyPaidByWallet) {
      return context.translate(LanguageLabelKeys.paidFullyByWallet);
    }
    if (!hasWallet) {
      return hasRemaining
          ? remainingLabel(context)
          : context.translate(LanguageLabelKeys.total);
    }
    final prefixKey = (isCod && !isDelivered)
        ? LanguageLabelKeys.payVia
        : LanguageLabelKeys.paidVia;
    return '${context.translate(prefixKey)} ${context.translate(LanguageLabelKeys.wallet)}+${methodName(context)}';
  }

  double get combinedTotalAmount => wallet + remaining;
}
