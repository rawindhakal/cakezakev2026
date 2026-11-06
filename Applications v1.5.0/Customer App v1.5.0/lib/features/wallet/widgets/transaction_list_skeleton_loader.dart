import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors `_TransactionTile`'s / `WalletTransactionItem`'s shape (icon box,
/// title/subtitle, status/type badge, date/amount row) so neither
/// transaction history list jumps layout once real tiles swap in.
class TransactionListSkeletonLoader extends StatelessWidget {
  final int itemCount;

  /// Wallet history uses an outlined card; the payment transactions list
  /// uses a shadowed one — matches whichever real tile is being mirrored.
  final bool outlined;

  final bool shrinkWrap;

  const TransactionListSkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.outlined = false,
    this.shrinkWrap = false,
  });

  Widget _tile(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingS),
      decoration: outlined
          ? AppDecorations.outlinedCard(
              color: context.cs.surface,
              borderColor: context.cs.outline,
            )
          : AppDecorations.shadowedCard(
              color: Theme.of(context).cardColor,
              shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
            ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .center,
              spacing: ThemeConstants.spaceM,
              children: [
                ShimmerBox(color, width: 40, height: 40, radius: AppRadius.r8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceS,
                    children: [
                      ShimmerBox(color, width: 130, height: 14),
                      ShimmerBox(color, width: 90, height: 11),
                    ],
                  ),
                ),
                ShimmerBox(color, width: 60, height: 20, radius: AppRadius.r20),
              ],
            ),
            AppSpacing.h10,
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                ShimmerBox(color, width: 100, height: 11),
                ShimmerBox(color, width: 70, height: 16),
              ],
            ),
          ],
        ),
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
        itemBuilder: (_, _) => _tile(context, color),
      ),
    );
  }
}
