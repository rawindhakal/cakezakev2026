import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors the checkout/cart screen's loaded layout (cart items card, bill
/// summary card) so there's no layout jump once the real cart swaps in.
class CheckoutSkeletonLoader extends StatelessWidget {
  const CheckoutSkeletonLoader({super.key});

  Widget _cartItemsCard(Color color) {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(color, width: 160, height: 14),
          AppSpacing.h12,
          for (var i = 0; i < 3; i++) ...[
            Row(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceM,
              children: [
                ShimmerBox(color, width: 56, height: 56, radius: AppRadius.r8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceS,
                    children: [
                      ShimmerBox(color, width: double.infinity, height: 13),
                      ShimmerBox(color, width: 70, height: 12),
                    ],
                  ),
                ),
                ShimmerBox(color, width: 60, height: 28, radius: AppRadius.r8),
              ],
            ),
            if (i != 2) AppSpacing.h16,
          ],
        ],
      ),
    );
  }

  Widget _row(Color color) {
    return CheckoutCard(
      child: Row(
        spacing: ThemeConstants.spaceM,
        children: [
          ShimmerBox(color, width: 22, height: 22, radius: AppRadius.r6),
          Expanded(child: ShimmerBox(color, height: 13)),
        ],
      ),
    );
  }

  Widget _billSummaryCard(Color color) {
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(color, width: 130, height: 14),
          AppSpacing.h12,
          for (var i = 0; i < 4; i++) ...[
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                ShimmerBox(color, width: 90, height: 12),
                ShimmerBox(color, width: 60, height: 12),
              ],
            ),
            if (i != 3) AppSpacing.h8,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          0,
        ),
        children: [
          _cartItemsCard(color),
          AppSpacing.h12,
          _row(color),
          AppSpacing.h12,
          _row(color),
          AppSpacing.h12,
          _billSummaryCard(color),
          AppSpacing.h100,
        ],
      ),
    );
  }
}
