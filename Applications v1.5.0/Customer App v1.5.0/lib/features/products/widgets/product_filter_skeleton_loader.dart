import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors the filter sheet's two-pane shape (left category rail + right
/// option list) so the sheet doesn't jump layout once the filter data lands.
class ProductFilterSkeletonLoader extends StatelessWidget {
  final int railItemCount;
  final int optionItemCount;

  const ProductFilterSkeletonLoader({
    super.key,
    this.railItemCount = 5,
    this.optionItemCount = 8,
  });

  Widget _railItem(Color color, double width) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
        vertical: ThemeConstants.paddingM,
      ),
      child: ShimmerBox(color, width: width, height: 13),
    );
  }

  Widget _optionItem(Color color, double width) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
        vertical: ThemeConstants.paddingM,
      ),
      child: Row(
        children: [
          ShimmerBox(color, width: 32, height: 32, radius: AppRadius.r6),
          AppSpacing.w10,
          Expanded(child: ShimmerBox(color, width: width, height: 13)),
          AppSpacing.w8,
          ShimmerBox(color, width: 20, height: 20, radius: AppRadius.r4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: 110,
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingS,
              ),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: railItemCount,
              itemBuilder: (_, index) =>
                  _railItem(color, index.isEven ? 62 : 48),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: context.cs.outlineVariant,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingXS,
              ),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: optionItemCount,
              itemBuilder: (_, index) =>
                  _optionItem(color, index.isEven ? double.infinity : 110),
            ),
          ),
        ],
      ),
    );
  }
}
