import 'dart:math' as math;

import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/wave_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class RecentSearchesView extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  const RecentSearchesView({
    super.key,
    required this.recentSearches,
    required this.onTap,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(
        start: ThemeConstants.paddingL,
        end: ThemeConstants.paddingL,
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.paddingXS,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: ThemeConstants.paddingL,
              bottom: ThemeConstants.paddingM,
            ),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                WaveText(
                  context.translate(LanguageLabelKeys.recentSearches),
                  style: context.tt.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: AppText(context.translate(LanguageLabelKeys.clearAll)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: ThemeConstants.spaceS,
            runSpacing: ThemeConstants.spaceS,
            children: recentSearches
                .asMap()
                .entries
                .map(
                  (e) => _RecentSearchChip(
                    query: e.value,
                    index: e.key,
                    onTap: () => onTap(e.value),
                    onRemove: () => onRemove(e.value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Admin-driven "Trending Products" chips (home `search_suggestions`) —
/// same pulse chip as recent searches, but primary-tinted with a trending
/// icon and no remove action.
class TrendingSearchesView extends StatelessWidget {
  final List<String> trendingSearches;
  final ValueChanged<String> onTap;
  final Key? titleKey;

  const TrendingSearchesView({
    super.key,
    required this.trendingSearches,
    required this.onTap,
    this.titleKey,
  });

  /// Estimated width of all chips laid out in a single row — mirrors
  /// [_RecentSearchChip]'s padding, icon, gap, text and border.
  double _singleRowWidth(BuildContext context, double maxChipWidth) {
    final style = context.tt.bodySmall?.copyWith(fontSize: 13);
    final textScaler = MediaQuery.textScalerOf(context);
    var total = 0.0;
    for (final query in trendingSearches) {
      final painter = TextPainter(
        text: TextSpan(text: query, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      final chip =
          ThemeConstants.paddingM * 2 +
          ThemeConstants.iconXS +
          6 +
          painter.width +
          2;
      painter.dispose();
      total += math.min(chip, maxChipWidth);
    }
    return total + ThemeConstants.spaceS * (trendingSearches.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    // Chip text is Flexible, which needs a bounded width inside the
    // horizontal scroll — cap each chip so long names ellipsize.
    final maxChipWidth = MediaQuery.sizeOf(context).width * 0.7;
    // One row while everything fits; once it would overflow, switch to two
    // rows that scroll horizontally so a long list doesn't fill the screen.
    final available =
        MediaQuery.sizeOf(context).width - ThemeConstants.paddingL * 2;
    final rowCount = _singleRowWidth(context, maxChipWidth) > available ? 2 : 1;
    // Alternate items between rows to keep row widths balanced.
    final rows = [
      for (var r = 0; r < rowCount; r++)
        [
          for (var i = r; i < trendingSearches.length; i += rowCount)
            _RecentSearchChip(
              query: trendingSearches[i],
              index: i,
              onTap: () => onTap(trendingSearches[i]),
              trending: true,
            ),
        ],
    ];
    // Full width so the parent's centered Column doesn't center a short list.
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: ThemeConstants.paddingL,
              end: ThemeConstants.paddingL,
              top: ThemeConstants.paddingXL,
              bottom: ThemeConstants.paddingM,
            ),
            child: WaveText(
              key: titleKey,
              context.translate(
                LanguageLabelKeys.trendingProducts,
                fallback: 'Trending Products',
              ),
              style: context.tt.bodyLarge?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
              // Room for the chips' pulse scale so edges don't clip.
              vertical: 2,
            ),
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceS,
              children: [
                for (final row in rows)
                  if (row.isNotEmpty)
                    Row(
                      spacing: ThemeConstants.spaceS,
                      children: [
                        for (final chip in row)
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxChipWidth),
                            child: chip,
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

class _RecentSearchChip extends StatefulWidget {
  final String query;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool trending;

  const _RecentSearchChip({
    required this.query,
    required this.index,
    required this.onTap,
    this.onRemove,
    this.trending = false,
  });

  @override
  State<_RecentSearchChip> createState() => _RecentSearchChipState();
}

// Continuous gentle breathing pulse: each chip softly scales up/down
// forever, phase staggered by index so they don't all move in lockstep.
class _RecentSearchChipState extends State<_RecentSearchChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _phase;

  @override
  void initState() {
    super.initState();
    _phase = (widget.index % 4) * 0.25;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trending = widget.trending;
    final primary = context.cs.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (_controller.value + _phase) * 2 * math.pi;
        final scale = 1.0 + math.sin(angle) * 0.03;
        return Transform.scale(scale: scale, child: child);
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadius.r20,
        child: Container(
          padding: EdgeInsetsDirectional.only(
            start: ThemeConstants.paddingM,
            end: widget.onRemove != null
                ? ThemeConstants.paddingXS
                : ThemeConstants.paddingM,
            top: ThemeConstants.paddingXS,
            bottom: ThemeConstants.paddingXS,
          ),
          // Trending: soft primary tint + half-strength primary border, so
          // chips read as highlighted without competing with primary CTAs;
          // text stays onSurface for contrast.
          decoration: AppDecorations.box(
            color: trending
                ? primary.withValues(alpha: 0.06)
                : context.cs.surfaceContainer,
            borderRadius: AppRadius.r20,
            border: Border.all(
              color: trending
                  ? primary.withValues(alpha: 0.5)
                  : context.cs.outline,
            ),
          ),
          child: Row(
            mainAxisSize: .min,
            children: [
              if (trending)
                Icon(
                  Icons.trending_up_rounded,
                  size: ThemeConstants.iconXS,
                  color: primary,
                )
              else
                AppSvgIcon(
                  AssetsConstants.historyIcon,
                  size: ThemeConstants.iconXS,
                  color: context.cs.onSurfaceVariant,
                ),
              AppSpacing.w6,
              // Long product names (trending) would overflow the row.
              Flexible(
                child: AppText(
                  widget.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
                    color: context.cs.onSurface,
                  ),
                ),
              ),
              if (widget.onRemove != null) ...[
                AppSpacing.w4,
                InkWell(
                  onTap: widget.onRemove,
                  borderRadius: AppRadius.r20,
                  child: AppSvgIcon(
                    AssetsConstants.closeIcon,
                    size: ThemeConstants.iconXS,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
