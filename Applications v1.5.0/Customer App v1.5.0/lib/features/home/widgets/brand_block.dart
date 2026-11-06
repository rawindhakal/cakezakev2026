import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/brand_tile.dart';
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

class BrandBlock extends StatelessWidget {
  final List<Brands> brands;
  final double gap;
  final ValueChanged<Brands>? onTap;
  final SectionLayout layout;
  final int columns;
  final String? sectionTitle;
  final bool? showName;
  final double borderRadius;
  final ProductVariant variant;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final String? textColor;
  final String? itemTextColor;
  final String? bgImageAspect;

  const BrandBlock({
    super.key,
    required this.brands,
    this.gap = 0,
    this.onTap,
    this.layout = SectionLayout.horizontal,
    this.columns = 4,
    this.sectionTitle,
    this.showName,
    this.borderRadius = 0,
    this.variant = ProductVariant.defaultVariant,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.textColor,
    this.itemTextColor,
    this.bgImageAspect,
  });

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  // Server sizes tiles/grid cells for mobile — scale continuously with the
  // device's actual width on tablet (instead of one flat size) so bigger
  // tablets get proportionally bigger tiles, not just "a bit more than phone".
  double _tabletScale(BuildContext context) {
    if (!_isTablet(context)) return 1.0;
    final screenWidth = context.screenWidth;
    return (screenWidth / 500).clamp(1.6, 2.6);
  }

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();

    final itemRadius = borderRadius;
    final pad = gap;
    final scale = _tabletScale(context);
    final tileSize = 60.0 * scale;
    final circleRadius = 30.0 * scale;
    final gridExtent = 92.0 * scale;
    final labelFontSize = 11.0 * scale.clamp(1.0, 1.6);
    final labelWidth = 64.0 * scale;

    Widget content;

    if (layout == SectionLayout.horizontal) {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(horizontal: pad),
        child: Row(
          mainAxisSize: .min,
          children: List.generate(
            brands.length,
            (i) => Padding(
              padding: EdgeInsetsDirectional.only(end: gap * scale),
              child: BrandTile(
                imageUrl: brands[i].imageUrl ?? '',
                name: brands[i].name ?? '',
                borderRadius: itemRadius,
                size: tileSize,
                labelFontSize: labelFontSize,
                labelWidth: labelWidth,
                textColor: itemTextColor.toColor(),
                onTap: onTap != null ? () => onTap!(brands[i]) : null,
                showName: showName,
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
          children: List.generate(
            brands.length,
            (i) => Padding(
              padding: EdgeInsetsDirectional.only(end: gap * scale),
              child: BrandTile(
                imageUrl: brands[i].imageUrl ?? '',
                name: brands[i].name ?? '',
                shape: BrandTileShape.circle,
                size: circleRadius,
                labelFontSize: labelFontSize,
                labelWidth: labelWidth,
                textColor: itemTextColor.toColor(),
                onTap: onTap != null ? () => onTap!(brands[i]) : null,
                showName: showName,
              ),
            ),
          ),
        ),
      );
    } else {
      content = GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.symmetric(horizontal: pad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns.clamp(1, 10),
          mainAxisSpacing: gap * scale,
          crossAxisSpacing: gap * scale,
          mainAxisExtent: gridExtent,
        ),
        itemCount: brands.length,
        itemBuilder: (_, i) => BrandTile(
          imageUrl: brands[i].imageUrl ?? '',
          name: brands[i].name ?? '',
          borderRadius: itemRadius,
          size: tileSize,
          labelFontSize: labelFontSize,
          labelWidth: labelWidth,
          textColor: itemTextColor.toColor(),
          onTap: onTap != null ? () => onTap!(brands[i]) : null,
          showName: showName,
        ),
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
