import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Mirrors [PaymentMethodTile]'s shape (icon, label, radio) so the payment
/// method list doesn't jump layout once real tiles swap in.
class PaymentMethodsSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const PaymentMethodsSkeletonLoader({super.key, this.itemCount = 5});

  Widget _tile(Color color) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingS,
        vertical: ThemeConstants.paddingS,
      ),
      decoration: AppDecorations.box(
        borderRadius: AppRadius.r12,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          ShimmerBox(color, width: 44, height: 36, radius: AppRadius.r6),
          AppSpacing.w12,
          Expanded(
            child: ShimmerBox(color, width: double.infinity, height: 14),
          ),
          AppSpacing.w12,
          ShimmerBox(color, width: 22, height: 22, radius: AppRadius.r11),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.separated(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => AppSpacing.h10,
        itemBuilder: (_, _) => _tile(color),
      ),
    );
  }
}
