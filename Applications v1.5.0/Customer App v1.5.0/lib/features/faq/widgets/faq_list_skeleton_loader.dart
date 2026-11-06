import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [FaqTile]'s collapsed shape (question line + chevron) so the
/// FAQ list doesn't jump layout once real tiles swap in.
class FaqListSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;

  const FaqListSkeletonLoader({
    super.key,
    this.itemCount = 8,
    this.shrinkWrap = false,
  });

  Widget _tile(BuildContext context, Color color, double width) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingS),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r8,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      child: Row(
        children: [
          Expanded(child: ShimmerBox(color, width: width, height: 15)),
          AppSpacing.w10,
          ShimmerBox(color, width: 20, height: 20, radius: AppRadius.r4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        itemCount: itemCount,
        itemBuilder: (_, index) =>
            _tile(context, color, index.isEven ? double.infinity : 200),
      ),
    );
  }
}
