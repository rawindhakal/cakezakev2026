import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [OrderDetailScreen]/[EcommerceOrderDetailScreen]'s loaded layout
/// (header, customer info, items, price summary cards) so there's no
/// layout jump when the real content swaps in.
class OrderDetailSkeletonLoader extends StatelessWidget {
  const OrderDetailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _headerCard(color),
          AppSpacing.h12,
          _customerInfoCard(color),
          AppSpacing.h12,
          _itemsCard(color),
          AppSpacing.h12,
          _priceSummaryCard(color),
          AppSpacing.h80,
        ],
      ),
    );
  }

  Widget _headerCard(Color color) {
    return OrderDetailCard(
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                ShimmerBox(color, width: 140, height: 16),
                AppSpacing.h8,
                ShimmerBox(color, width: 100, height: 12),
                AppSpacing.h12,
                ShimmerBox(color, width: 80, height: 22, radius: AppRadius.r16),
              ],
            ),
          ),
          ShimmerBox(color, width: 64, height: 64, radius: AppRadius.r12),
        ],
      ),
    );
  }

  Widget _customerInfoCard(Color color) {
    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(color, width: 120, height: 14),
          AppSpacing.h12,
          Row(
            spacing: ThemeConstants.spaceS,
            children: [
              ShimmerBox(color, width: 18, height: 18),
              Expanded(child: ShimmerBox(color, height: 12)),
            ],
          ),
          AppSpacing.h8,
          Row(
            spacing: ThemeConstants.spaceS,
            children: [
              ShimmerBox(color, width: 18, height: 18),
              Expanded(child: ShimmerBox(color, height: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(Color color) {
    return OrderDetailCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(color, width: 100, height: 14),
          AppSpacing.h12,
          for (var i = 0; i < 2; i++) ...[
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
                      ShimmerBox(color, width: 80, height: 12),
                    ],
                  ),
                ),
                ShimmerBox(color, width: 48, height: 13),
              ],
            ),
            if (i == 0) AppSpacing.h16,
          ],
        ],
      ),
    );
  }

  Widget _priceSummaryCard(Color color) {
    return OrderDetailCard(
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
}
