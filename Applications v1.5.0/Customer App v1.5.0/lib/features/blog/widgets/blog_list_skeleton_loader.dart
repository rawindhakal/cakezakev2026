import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [BlogCard]'s shape (image, category/date row, title, description,
/// meta row) so the blog list doesn't jump layout once real cards swap in.
class BlogListSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;

  const BlogListSkeletonLoader({
    super.key,
    this.itemCount = 4,
    this.shrinkWrap = false,
  });

  Widget _card(BuildContext context, Color color) {
    return Container(
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r10,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(
            color,
            width: double.infinity,
            height: 180,
            radius: AppRadius.top10,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Row(
                  children: [
                    ShimmerBox(
                      color,
                      width: 60,
                      height: 20,
                      radius: AppRadius.r4,
                    ),
                    const Spacer(),
                    ShimmerBox(color, width: 70, height: 12),
                  ],
                ),
                AppSpacing.h10,
                ShimmerBox(color, width: double.infinity, height: 15),
                AppSpacing.h6,
                ShimmerBox(color, width: 120, height: 15),
                AppSpacing.h10,
                ShimmerBox(color, width: double.infinity, height: 13),
                AppSpacing.h6,
                ShimmerBox(color, width: 180, height: 13),
                AppSpacing.h10,
                Row(
                  spacing: ThemeConstants.spaceM,
                  children: [
                    ShimmerBox(color, width: 40, height: 12),
                    ShimmerBox(color, width: 40, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        itemCount: itemCount,
        separatorBuilder: (_, _) => AppSpacing.h12,
        itemBuilder: (_, _) => _card(context, color),
      ),
    );
  }
}
