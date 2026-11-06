import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Home layout is server-driven — the real section mix (banner, category
/// row, product grid, brand row …) is unknown until the API responds, so
/// this can't mirror the exact incoming layout. Instead it stacks the
/// section shapes that show up most often, all pulsing off one shared
/// [ShimmerBuilder], so the first load reads as "content is arriving"
/// rather than a blank screen.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key});

  static const BorderRadius _circle = AppRadius.r28;

  @override
  Widget build(BuildContext context) {
    return ShimmerBuilder(
      builder: (context, color) => Column(
        crossAxisAlignment: .start,
        children: [
          AppSpacing.h16,
          _bannerSection(color),
          AppSpacing.h16,
          _categoryRowSection(color),
          AppSpacing.h20,
          _productRowSection(color),
          AppSpacing.h20,
          _brandRowSection(color),
          AppSpacing.h20,
          _productGridSection(color),
          AppSpacing.h16,
        ],
      ),
    );
  }

  Widget _bannerSection(Color color) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingL,
      ),
      child: ShimmerBox(
        color,
        width: double.infinity,
        height: 160,
        radius: AppRadius.r14,
      ),
    );
  }

  Widget _categoryRowSection(Color color) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
        ),
        itemCount: 6,
        separatorBuilder: (context, i) => AppSpacing.w16,
        itemBuilder: (context, i) => Column(
          mainAxisSize: .min,
          children: [
            ShimmerBox(color, width: 56, height: 56, radius: _circle),
            AppSpacing.h6,
            ShimmerBox(color, width: 48, height: 10),
          ],
        ),
      ),
    );
  }

  Widget _productRowSection(Color color) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            0,
            ThemeConstants.paddingL,
            ThemeConstants.paddingS,
          ),
          child: ShimmerBox(color, width: 140, height: 16),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
            ),
            itemCount: 4,
            separatorBuilder: (context, i) => AppSpacing.w12,
            itemBuilder: (context, i) =>
                SizedBox(width: 140, child: _productCard(color)),
          ),
        ),
      ],
    );
  }

  Widget _productGridSection(Color color) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingL,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(color, width: 140, height: 16),
          AppSpacing.h10,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, i) => _productCard(color),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Color color) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        AspectRatio(
          aspectRatio: 0.85,
          child: ShimmerBox(
            color,
            width: double.infinity,
            height: double.infinity,
            radius: AppRadius.r8,
          ),
        ),
        AppSpacing.h8,
        ShimmerBox(color, width: 90, height: 13),
        AppSpacing.h6,
        ShimmerBox(color, width: 60, height: 12),
      ],
    );
  }

  Widget _brandRowSection(Color color) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
        ),
        itemCount: 5,
        separatorBuilder: (context, i) => AppSpacing.w14,
        itemBuilder: (context, i) =>
            ShimmerBox(color, width: 64, height: 64, radius: _circle),
      ),
    );
  }
}
