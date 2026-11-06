import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/features/orders/widgets/bill_row.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';

/// Full payment breakdown block for order-detail billing-summary cards.
/// When both wallet and a remaining method paid part of the order, each
/// gets its own row ("Paid via Wallet", "Collect from Customer" / "Paid via
/// Razorpay") in the same style, and the Total row below is a plain sum —
/// no single row tries to name both methods, and no separate payment-method
/// badge repeats the same information. When only one method was used, that
/// row alone is shown and doubles as the Total. When there's cash still to
/// collect, a standalone callout restates the amount so it's impossible to
/// miss at a glance — no confirm/action button, just the number.
class PaymentSummarySection extends StatelessWidget {
  final PaymentBreakdown breakdown;
  final String symbol;
  const PaymentSummarySection({
    super.key,
    required this.breakdown,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Container(height: 1, color: context.cs.outlineVariant),
        AppSpacing.h10,
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Expanded(
              child: AppText(
                breakdown.totalLabel(context),
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
            AppText(
              '$symbol${breakdown.totalAmount.trimmedFixed()}',
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.cs.onSurface,
              ),
            ),
          ],
        ),
        if (breakdown.isCombined) ...[
          AppSpacing.h10,
          BillRow(
            label: breakdown.walletLabel(context),
            value: '$symbol${breakdown.wallet.trimmedFixed()}',
          ),
          AppSpacing.h10,
          BillRow(
            label: breakdown.remainingLabel(context),
            value: '$symbol${breakdown.remaining.trimmedFixed()}',
          ),
        ],
        if (breakdown.mustCollectCash) ...[
          AppSpacing.h12,
          CollectFromCustomerCallout(breakdown: breakdown, symbol: symbol),
        ],
      ],
    );
  }
}

/// Warning-colored "Collect from Customer ₹XX" callout — the one place in
/// the UI that says cash still needs collecting. Shared by the order-detail
/// billing-summary card and the order-listing cards so the signal (and its
/// styling) is identical everywhere, not reinvented per screen.
class CollectFromCustomerCallout extends StatelessWidget {
  final PaymentBreakdown breakdown;
  final String symbol;
  const CollectFromCustomerCallout({
    super.key,
    required this.breakdown,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: context.cs.errorContainer.withValues(alpha: 0.1),
        borderRadius: AppRadius.r10,
        border: Border.all(
          color: context.cs.errorContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.collectFromCustomer),
            style: context.tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.errorContainer,
            ),
          ),
          AppText(
            '$symbol${breakdown.collectAmount.trimmedFixed()}',
            style: context.tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.cs.errorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
