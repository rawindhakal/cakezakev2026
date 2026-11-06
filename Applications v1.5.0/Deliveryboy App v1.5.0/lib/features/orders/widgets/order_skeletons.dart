import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';

/// Which order-card layout a [OrderListSkeleton] should mimic.
enum OrderSkeletonVariant { quick, ecommerce, returns }

/// Shimmering stand-in for the order lists — each placeholder card mirrors the
/// real [OrderCard] / [EcommerceOrderCard] / [ReturnOrderCard] geometry so the
/// layout does not jump when the data arrives.
class OrderListSkeleton extends StatelessWidget {
  final int itemCount;
  final OrderSkeletonVariant variant;

  const OrderListSkeleton({
    super.key,
    this.itemCount = 5,
    this.variant = OrderSkeletonVariant.quick,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, ThemeConstants.paddingXXL),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => switch (variant) {
          OrderSkeletonVariant.quick => const _QuickOrderCardSkeleton(),
          OrderSkeletonVariant.ecommerce => const _EcommerceOrderCardSkeleton(),
          OrderSkeletonVariant.returns => const _ReturnOrderCardSkeleton(),
        },
      ),
    );
  }
}

/// Header block shared by every order-card skeleton — id line, date line and
/// the trailing status chip.
class _CardHeaderSkeleton extends StatelessWidget {
  const _CardHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              ShimmerBox(width: 118, height: 14, borderRadius: AppRadius.r6),
              AppSpacing.h8,
              ShimmerBox(width: 92, height: 10, borderRadius: AppRadius.r6),
            ],
          ),
        ),
        AppSpacing.w8,
        ShimmerBox(width: 78, height: 24, borderRadius: AppRadius.r20),
      ],
    );
  }
}

/// Payment badge + total amount row that closes every order card.
class _CardFooterSkeleton extends StatelessWidget {
  const _CardFooterSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        ShimmerBox(width: 72, height: 22, borderRadius: AppRadius.r8),
        ShimmerBox(width: 64, height: 15, borderRadius: AppRadius.r6),
      ],
    );
  }
}

/// One product line — optional leading thumbnail, name + variant, trailing price.
class _ItemLineSkeleton extends StatelessWidget {
  final double nameWidth;
  final double? thumbSize;

  const _ItemLineSkeleton({required this.nameWidth, this.thumbSize});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        if (thumbSize != null) ...[
          ShimmerBox(
            width: thumbSize,
            height: thumbSize!,
            borderRadius: AppRadius.r8,
          ),
          AppSpacing.w10,
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              ShimmerBox(
                width: nameWidth,
                height: 12,
                borderRadius: AppRadius.r6,
              ),
              AppSpacing.h6,
              ShimmerBox(
                width: nameWidth * 0.55,
                height: 10,
                borderRadius: AppRadius.r6,
              ),
            ],
          ),
        ),
        AppSpacing.w8,
        const ShimmerBox(width: 46, height: 12, borderRadius: AppRadius.r6),
      ],
    );
  }
}

/// Hairline stand-in for the dividers inside the real cards.
class _SkeletonDivider extends StatelessWidget {
  const _SkeletonDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: 10),
      child: ShimmerBox(height: 1, borderRadius: AppRadius.r2),
    );
  }
}

/// Padded, outlined shell matching the detail-screen card containers.
class _SkeletonCard extends StatelessWidget {
  final EdgeInsetsDirectional padding;
  final EdgeInsetsDirectional margin;
  final Widget child;

  const _SkeletonCard({
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(14),
    this.margin = const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: AppDecorations.card(
        borderRadius: AppRadius.r14,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: child,
    );
  }
}

class _QuickOrderCardSkeleton extends StatelessWidget {
  const _QuickOrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      padding: EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      margin: EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _CardHeaderSkeleton(),
          _SkeletonDivider(),
          AppSpacing.h4,
          _ItemLineSkeleton(nameWidth: 170),
          AppSpacing.h12,
          _ItemLineSkeleton(nameWidth: 140),
          _SkeletonDivider(),
          _CardFooterSkeleton(),
        ],
      ),
    );
  }
}

class _EcommerceOrderCardSkeleton extends StatelessWidget {
  const _EcommerceOrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      padding: EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      margin: EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _CardHeaderSkeleton(),
          _SkeletonDivider(),
          _ItemLineSkeleton(nameWidth: 160, thumbSize: 48),
          AppSpacing.h8,
          ShimmerBox(width: 96, height: 10, borderRadius: AppRadius.r6),
          _SkeletonDivider(),
          _CardFooterSkeleton(),
        ],
      ),
    );
  }
}

class _ReturnOrderCardSkeleton extends StatelessWidget {
  const _ReturnOrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      decoration: AppDecorations.card(
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: const Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, ThemeConstants.paddingM),
            child: _CardHeaderSkeleton(),
          ),
          ShimmerBox(height: 1, borderRadius: AppRadius.r2),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, ThemeConstants.paddingM),
            child: _ItemLineSkeleton(nameWidth: 150),
          ),
          ShimmerBox(height: 1, borderRadius: AppRadius.r2),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
            child: _CardFooterSkeleton(),
          ),
        ],
      ),
    );
  }
}

/// Full-page shimmer for the order-detail screens: pickup/delivery route card,
/// timeline card, items card, bill summary and the pinned action button.
class OrderDetailSkeleton extends StatelessWidget {
  /// Mimics the "Update status" button pinned to the bottom of the real screen.
  final bool showBottomBar;

  /// The return-detail screen has no items list, only a single product block.
  final bool showItemsCard;

  const OrderDetailSkeleton({
    super.key,
    this.showBottomBar = true,
    this.showItemsCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.bottomSafePadding;

    return Stack(
      children: [
        ShimmerLoading(
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingL,
              ThemeConstants.paddingL,
              bottomPad + (showBottomBar ? 110 : 16),
            ),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const _RouteCardSkeleton(),
              const _TimelineCardSkeleton(),
              if (showItemsCard) const _ItemsCardSkeleton(),
              const _BillingCardSkeleton(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pickup → delivery card: two route stops joined by the connector rail, each
/// with title, name, phone, address and the action-chip row.
class _RouteCardSkeleton extends StatelessWidget {
  const _RouteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SkeletonCard(
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: .start,
              children: [
                const _RouteIconSkeleton(showLine: true),
                AppSpacing.w12,
                const Expanded(child: _RouteStopSkeleton()),
              ],
            ),
          ),
          AppSpacing.h4,
          Row(
            crossAxisAlignment: .start,
            children: [
              const _RouteIconSkeleton(showLine: false),
              AppSpacing.w12,
              const Expanded(child: _RouteStopSkeleton(addressLines: 2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteIconSkeleton extends StatelessWidget {
  final bool showLine;
  const _RouteIconSkeleton({required this.showLine});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: AppDecorations.circle(
            color: context.cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
        if (showLine)
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsetsDirectional.symmetric(vertical: 2),
              decoration: AppDecorations.card(
                color: context.cs.onSurface.withValues(alpha: 0.08),
                borderRadius: AppRadius.r2,
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteStopSkeleton extends StatelessWidget {
  final int addressLines;
  const _RouteStopSkeleton({this.addressLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        const SizedBox(
          height: 40,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ShimmerBox(
              width: 104,
              height: 13,
              borderRadius: AppRadius.r6,
            ),
          ),
        ),
        const ShimmerBox(width: 140, height: 12, borderRadius: AppRadius.r6),
        AppSpacing.h6,
        const ShimmerBox(width: 116, height: 10, borderRadius: AppRadius.r6),
        AppSpacing.h6,
        for (var i = 0; i < addressLines; i++) ...[
          FractionallySizedBox(
            widthFactor: i == addressLines - 1 ? 0.72 : 1,
            child: const ShimmerBox(height: 10, borderRadius: AppRadius.r6),
          ),
          AppSpacing.h4,
        ],
        AppSpacing.h6,
        const Row(
          children: [
            ShimmerBox(width: 33, height: 33, borderRadius: AppRadius.r10),
            AppSpacing.w10,
            ShimmerBox(width: 33, height: 33, borderRadius: AppRadius.r10),
            AppSpacing.w10,
            Expanded(
              child: ShimmerBox(height: 33, borderRadius: AppRadius.r10),
            ),
          ],
        ),
        AppSpacing.h4,
      ],
    );
  }
}

/// "Track order" card — heading plus the last two timeline steps and the
/// see-more affordance.
class _TimelineCardSkeleton extends StatelessWidget {
  const _TimelineCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      padding: EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          ShimmerBox(width: 96, height: 13, borderRadius: AppRadius.r6),
          AppSpacing.h16,
          _TimelineStepSkeleton(showLine: true),
          _TimelineStepSkeleton(showLine: false),
          AppSpacing.h4,
          Center(
            child: ShimmerBox(
              width: 84,
              height: 12,
              borderRadius: AppRadius.r6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStepSkeleton extends StatelessWidget {
  final bool showLine;
  const _TimelineStepSkeleton({required this.showLine});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: AppDecorations.circle(
                  color: context.cs.onSurface.withValues(alpha: 0.08),
                ),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsetsDirectional.symmetric(vertical: 2),
                    decoration: AppDecorations.card(
                      color: context.cs.onSurface.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r2,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.w12,
          const Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  ShimmerBox(
                    width: 132,
                    height: 12,
                    borderRadius: AppRadius.r6,
                  ),
                  AppSpacing.h6,
                  ShimmerBox(width: 92, height: 10, borderRadius: AppRadius.r6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Items card — section header, then thumbnail rows split by hairlines.
class _ItemsCardSkeleton extends StatelessWidget {
  const _ItemsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    const rowWidths = [180.0, 150.0, 168.0];

    return _SkeletonCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, ThemeConstants.paddingM),
            child: ShimmerBox(
              width: 86,
              height: 13,
              borderRadius: AppRadius.r6,
            ),
          ),
          const ShimmerBox(height: 1, borderRadius: AppRadius.r2),
          for (var i = 0; i < rowWidths.length; i++) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, ThemeConstants.paddingM),
              child: _ItemLineSkeleton(nameWidth: rowWidths[i], thumbSize: 60),
            ),
            if (i < rowWidths.length - 1)
              const ShimmerBox(height: 1, borderRadius: AppRadius.r2),
          ],
        ],
      ),
    );
  }
}

/// Bill summary — charge rows, the total line and the payment-method row.
class _BillingCardSkeleton extends StatelessWidget {
  const _BillingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    const labelWidths = [88.0, 112.0, 96.0, 78.0];

    return _SkeletonCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, ThemeConstants.paddingM),
            child: ShimmerBox(
              width: 104,
              height: 13,
              borderRadius: AppRadius.r6,
            ),
          ),
          const ShimmerBox(height: 1, borderRadius: AppRadius.r2),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, 14),
            child: Column(
              children: [
                for (final width in labelWidths)
                  _BillRowSkeleton(labelWidth: width),
                AppSpacing.h4,
                ShimmerBox(height: 1, borderRadius: AppRadius.r2),
                AppSpacing.h12,
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    ShimmerBox(
                      width: 56,
                      height: 14,
                      borderRadius: AppRadius.r6,
                    ),
                    ShimmerBox(
                      width: 76,
                      height: 16,
                      borderRadius: AppRadius.r6,
                    ),
                  ],
                ),
                AppSpacing.h12,
                ShimmerBox(height: 1, borderRadius: AppRadius.r2),
                AppSpacing.h12,
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    ShimmerBox(
                      width: 92,
                      height: 11,
                      borderRadius: AppRadius.r6,
                    ),
                    ShimmerBox(
                      width: 72,
                      height: 22,
                      borderRadius: AppRadius.r8,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRowSkeleton extends StatelessWidget {
  final double labelWidth;
  const _BillRowSkeleton({required this.labelWidth});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          ShimmerBox(width: labelWidth, height: 11, borderRadius: AppRadius.r6),
          const ShimmerBox(width: 54, height: 11, borderRadius: AppRadius.r6),
        ],
      ),
    );
  }
}
