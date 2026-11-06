import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/category_tile.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/home/models/enums/product_block_enums.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/section_layout.dart';
import 'package:customer/features/home/utils/responsive_height_helper.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CategoryBlock extends StatelessWidget {
  final List<Categories> categories;
  final int columns;
  final double gap;
  final double borderRadius;
  final ValueChanged<Categories>? onTap;
  final SectionLayout layout;
  final String? sectionTitle;
  final ProductVariant variant;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final String? textColor;
  final String? itemTextColor;
  final String? bgImageAspect;

  const CategoryBlock({
    super.key,
    required this.categories,
    this.columns = 4,
    this.gap = 0,
    this.borderRadius = 0,
    this.onTap,
    this.layout = SectionLayout.grid,
    this.sectionTitle,
    this.variant = ProductVariant.defaultVariant,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.textColor,
    this.itemTextColor,
    this.bgImageAspect,
  });

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  // Server sizes tiles for mobile — scale continuously with the device's
  // actual width on tablet (instead of one flat size) so bigger tablets get
  // proportionally bigger tiles, not just "a bit more than phone".
  double _tabletScale(BuildContext context) {
    if (!_isTablet(context)) return 1.0;
    final screenWidth = context.screenWidth;
    return (screenWidth / 500).clamp(1.6, 2.6);
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final itemRadius = borderRadius;
    final pad = gap;
    final scale = _tabletScale(context);
    // gap comes from the admin/API config tuned for phone tile sizes — scale it with
    // the tiles themselves so tablet spacing doesn't collapse relative to bigger tiles.
    final scaledGap = gap * scale;
    final imageSize = 60.0 * scale;
    final circleRadius = 30.0 * scale;
    final labelFontSize = 11.0 * scale.clamp(1.0, 1.6);
    final labelWidth = 64.0 * scale;
    // Measured against the real theme font (not a flat multiplier) — a
    // guessed constant here silently drifted from the actual 2-line label
    // height on tablet's larger scale, overflowing the grid cell's tight
    // (childAspectRatio-derived) height by a few px.
    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: labelFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 2,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: labelWidth);
    final labelHeight = labelPainter.height * 2 + 4;
    final cellHeight = imageSize + 4.0 + labelHeight;

    Widget content;

    if (layout == SectionLayout.horizontal) {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(horizontal: pad),
        child: Row(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: List.generate(
            categories.length,
            (i) => Padding(
              padding: EdgeInsetsDirectional.only(end: scaledGap),
              child: CategoryTile(
                imageUrl: categories[i].imageUrl ?? '',
                name: categories[i].name ?? '',
                borderRadius: itemRadius,
                imageSize: imageSize,
                labelFontSize: labelFontSize,
                labelWidth: labelWidth,
                textColor: itemTextColor.toColor(),
                onTap: onTap != null ? () => onTap!(categories[i]) : null,
              ),
            ),
          ),
        ),
      );
    } else if (layout == SectionLayout.circular) {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(horizontal: pad),
        child: Row(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: List.generate(
            categories.length,
            (i) => Padding(
              padding: EdgeInsetsDirectional.only(end: scaledGap),
              child: CategoryTile(
                imageUrl: categories[i].imageUrl ?? '',
                name: categories[i].name ?? '',
                shape: CategoryTileShape.circle,
                imageSize: circleRadius * 2,
                labelFontSize: labelFontSize,
                labelWidth: labelWidth,
                textColor: itemTextColor.toColor(),
                onTap: onTap != null ? () => onTap!(categories[i]) : null,
              ),
            ),
          ),
        ),
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final cols = columns.clamp(1, 10);
          final cellWidth =
              (constraints.maxWidth - pad * 2 - scaledGap * (cols - 1)) / cols;
          final ratio = (cellWidth / cellHeight).clamp(0.4, 2.0);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.symmetric(horizontal: pad),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: scaledGap,
              crossAxisSpacing: scaledGap,
              childAspectRatio: ratio,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) => CategoryTile(
              imageUrl: categories[i].imageUrl ?? '',
              name: categories[i].name ?? '',
              borderRadius: itemRadius,
              imageSize: imageSize,
              labelFontSize: labelFontSize,
              labelWidth: labelWidth,
              textColor: itemTextColor.toColor(),
              onTap: onTap != null ? () => onTap!(categories[i]) : null,
            ),
          );
        },
      );
    }

    final showMeta = variant != ProductVariant.defaultVariant;

    if (showMeta && sectionTitle?.isNotEmpty == true) {
      final titleColor = textColor.toColor() ?? context.cs.onSurface;
      content = Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingS,
              vertical: ThemeConstants.paddingS,
            ),
            child: AppText(
              sectionTitle!,
              style: context.tt.displayMedium?.copyWith(
                fontSize: 16 * scale.clamp(1.0, 1.6),
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          content,
        ],
      );
    }

    if (showMeta &&
        variant == ProductVariant.withBackground &&
        backgroundImageUrl?.isNotEmpty == true) {
      final bgUrl = backgroundImageUrl!;
      final bgContent = content;
      content = LayoutBuilder(
        builder: (ctx, constraints) {
          final ratio = ResponsiveHeightHelper.parseAspectRatio(bgImageAspect);
          final minHeight = ratio != null
              ? ResponsiveHeightHelper.calculateFromAspect(
                  imageAspect: bgImageAspect,
                  context: ctx,
                  renderWidth: constraints.maxWidth,
                )
              : 0.0;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              width: double.infinity,
              decoration: AppDecorations.box(
                image: DecorationImage(
                  image: AppNetworkImage.provider(bgUrl),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                ),
              ),
              child: bgContent,
            ),
          );
        },
      );
    } else if (showMeta && variant == ProductVariant.withColor) {
      final bgColor = backgroundColor.toColor();
      if (bgColor != null) {
        content = ColoredBox(color: bgColor, child: content);
      }
    }

    return content;
  }
}
