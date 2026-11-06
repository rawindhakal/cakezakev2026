import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/grid_layout_type.dart';
import 'package:customer/features/home/models/enums/product_block_enums.dart';
import 'package:customer/features/home/utils/home_redirect_handler.dart';
import 'package:customer/features/home/utils/responsive_height_helper.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

class GridBanner extends StatelessWidget {
  final List<Items> items;
  final int columns;
  final int rows;
  final GridLayoutType layoutType;
  final int gap;
  final int borderRadius;
  final String? imageAspect;
  final ValueChanged<Items>? onTap;
  final ProductVariant variant;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final String? textColor;
  final String? sectionTitle;
  final String? bgImageAspect;
  final int blockPadding;

  const GridBanner({
    super.key,
    required this.items,
    this.columns = 2,
    this.rows = 1,
    this.layoutType = GridLayoutType.grid,
    this.gap = 0,
    this.borderRadius = 0,
    this.imageAspect,
    this.onTap,
    this.variant = ProductVariant.defaultVariant,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.textColor,
    this.sectionTitle,
    this.bgImageAspect,
    this.blockPadding = 0,
  });

  String? _imageUrl(Items item, BuildContext context) {
    final width = context.screenWidth;
    final isTablet = width >= 600;

    if (isTablet) {
      return item.images?.tablet?.isNotEmpty == true
          ? item.images!.tablet!
          : item.imageUrl;
    } else {
      return item.images?.app?.isNotEmpty == true
          ? item.images!.app!
          : item.imageUrl;
    }
  }

  void _handleTap(BuildContext context, Items item) {
    handleHomeRedirectTap(
      context,
      redirectType: item.redirectType,
      redirectId: item.redirectId,
      redirectUrl: item.redirectUrl,
      redirectSlug: item.redirectSlug,
      redirectTitle: item.redirectTitle,
      redirectParams: item.redirectParams,
      hasChild: item.hasChild,
    );
  }

  double _calculateAspectRatio(BuildContext context, int effectiveColumns) {
    if (imageAspect == null || imageAspect!.isEmpty) {
      return 1.5;
    }

    // Gap applies between tiles and on both outer edges (start/end).
    final screenWidth = context.screenWidth;
    final itemWidth =
        (screenWidth - (gap.toDouble() * (effectiveColumns + 1))) /
        effectiveColumns;
    final itemHeight = ResponsiveHeightHelper.calculateFromAspect(
      imageAspect: imageAspect,
      context: context,
      renderWidth: itemWidth,
    );

    return itemWidth / itemHeight;
  }

  Widget _buildTile(BuildContext context, Items item) {
    final url = _imageUrl(item, context);
    return GestureDetector(
      onTap: () => _handleTap(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius.toDouble()),
        child: url != null
            ? AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                placeholder: ColoredBox(color: context.cs.outline),
                errorWidget: ColoredBox(color: context.cs.outline),
              )
            : ColoredBox(color: context.cs.outline),
      ),
    );
  }

  // Row-major fill per page: page holds up to `columns x rows` items, filled
  // left-to-right then top-to-bottom (like a normal grid). Once a page is
  // full, remaining items start a new page to the right — that's what
  // horizontal scroll reveals. The underlying GridView delegate only fills
  // column-major (cross axis first), so items are remapped into slots
  // (padded with null for empty trailing cells) before handing to it.
  List<Items?> _paginatedSlots(int effectiveColumns, int effectiveRows) {
    final pageCapacity = effectiveColumns * effectiveRows;
    final numPages = (items.length / pageCapacity).ceil();
    final slots = List<Items?>.filled(numPages * pageCapacity, null);
    for (var i = 0; i < items.length; i++) {
      final page = i ~/ pageCapacity;
      final posInPage = i % pageCapacity;
      final row = posInPage ~/ effectiveColumns;
      final col = posInPage % effectiveColumns;
      final globalColumn = page * effectiveColumns + col;
      slots[globalColumn * effectiveRows + row] = items[i];
    }
    // Trailing null slots only pad empty columns after the last used one —
    // drop them so the scroll extent stops right after the last item
    // instead of showing blank trailing columns.
    var end = slots.length;
    while (end > 0 && slots[end - 1] == null) {
      end--;
    }
    return slots.sublist(0, end);
  }

  Widget _buildScrollGrid(BuildContext context) {
    final effectiveRows = rows < 1 ? 1 : rows;
    final effectiveColumns = columns.clamp(1, 10);
    final screenWidth = context.screenWidth;
    final itemWidth =
        (screenWidth - (gap.toDouble() * (effectiveColumns - 1))) /
        effectiveColumns;
    final itemHeight = ResponsiveHeightHelper.calculateFromAspect(
      imageAspect: imageAspect,
      context: context,
      renderWidth: itemWidth,
    );
    final gridHeight =
        (itemHeight * effectiveRows) +
        (gap.toDouble() * (effectiveRows - 1)) +
        (gap.toDouble() * 2);
    final slots = _paginatedSlots(effectiveColumns, effectiveRows);

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: gap == 0
            ? const EdgeInsetsDirectional.symmetric(horizontal: 0)
            : EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: effectiveRows,
          mainAxisExtent: itemWidth,
          mainAxisSpacing: gap.toDouble(),
          crossAxisSpacing: gap.toDouble(),
        ),
        itemCount: slots.length,
        itemBuilder: (context, i) {
          final item = slots[i];
          if (item == null) return const SizedBox.shrink();
          final column = i ~/ effectiveRows;
          final lastColumn = (slots.length - 1) ~/ effectiveRows;
          final row = i % effectiveRows;
          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: column == 0 ? gap.toDouble() : 0,
              end: column == lastColumn ? gap.toDouble() : 0,
              top: row == 0 ? gap.toDouble() : 0,
              bottom: row == effectiveRows - 1 ? gap.toDouble() : 0,
            ),
            child: _buildTile(context, item),
          );
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (layoutType == GridLayoutType.scroll) {
      return _buildScrollGrid(context);
    }

    final effectiveColumns = items.length == 1 ? 1 : columns.clamp(1, 10);
    final aspectRatio = _calculateAspectRatio(context, effectiveColumns);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.all(gap.toDouble()),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveColumns,
        mainAxisSpacing: gap.toDouble(),
        crossAxisSpacing: gap.toDouble(),
        childAspectRatio: aspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildTile(context, items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final showMeta = variant != ProductVariant.defaultVariant;
    Widget gridContent = _buildGrid(context);
    final pad = blockPadding > 0 ? blockPadding.toDouble() : 0.0;

    Widget content = gridContent;

    if (showMeta && sectionTitle?.isNotEmpty == true) {
      final titleColor = textColor.toColor() ?? context.cs.onSurface;
      content = Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          // Grid already adds `gap` above its first row, so the title gets no
          // bottom padding of its own (unless gap is 0, so it doesn't touch).
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: ThemeConstants.paddingS,
              end: ThemeConstants.paddingS,
              top: ThemeConstants.paddingS,
              bottom: gap == 0 ? ThemeConstants.paddingS : 0,
            ),
            child: AppText(
              sectionTitle!,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          content,
        ],
      );
    }

    // Wraps title + grid together so blockPadding never sits between them.
    // Vertical only — both layouts already put `gap` on the start/end edges,
    // so horizontal blockPadding would double it.
    if (pad > 0) {
      content = Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: pad),
        child: content,
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

class GridBannerRow extends StatelessWidget {
  final List<Items> items;
  final int gap;
  final int borderRadius;
  final String? imageAspect;

  const GridBannerRow({
    super.key,
    required this.items,
    this.gap = 0,
    this.borderRadius = 0,
    this.imageAspect,
  });

  double _calculateAspectRatio(BuildContext context) {
    if (imageAspect == null || imageAspect!.isEmpty) {
      return 1.5;
    }

    final screenWidth = context.screenWidth;
    final itemWidth =
        (screenWidth - (gap.toDouble() * (items.length - 1))) / items.length;
    final itemHeight = ResponsiveHeightHelper.calculateFromAspect(
      imageAspect: imageAspect,
      context: context,
      renderWidth: itemWidth,
    );

    return itemWidth / itemHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final width = context.screenWidth;
    final isTablet = width >= 600;
    final aspectRatio = _calculateAspectRatio(context);
    return Row(
      children: items.asMap().entries.map((e) {
        final url = isTablet
            ? (e.value.images?.tablet?.isNotEmpty == true
                  ? e.value.images!.tablet!
                  : e.value.imageUrl)
            : (e.value.images?.app?.isNotEmpty == true
                  ? e.value.images!.app!
                  : e.value.imageUrl);
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: e.key == 0 ? gap.toDouble() : gap / 2,
              end: e.key == items.length - 1 ? gap.toDouble() : gap / 2,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius.toDouble()),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: url != null
                    ? AppNetworkImage(
                        url: url,
                        fit: BoxFit.cover,
                        placeholder: ColoredBox(color: context.cs.outline),
                        errorWidget: ColoredBox(color: context.cs.outline),
                      )
                    : ColoredBox(color: context.cs.outline),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
