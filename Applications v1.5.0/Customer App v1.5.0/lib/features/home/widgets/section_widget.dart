import 'package:customer/features/home/models/enums/block_type.dart';
import 'package:customer/features/home/models/enums/grid_layout_type.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/product_block_enums.dart';
import 'package:customer/features/home/models/enums/section_layout.dart';
import 'package:customer/features/home/models/enums/tab_style.dart';
import 'package:customer/features/home/widgets/banner_carousel.dart';
import 'package:customer/features/home/widgets/brand_block.dart';
import 'package:customer/features/home/widgets/category_block.dart';
import 'package:customer/features/home/widgets/grid_banner.dart';
import 'package:customer/features/home/widgets/product_block.dart';
import 'package:customer/features/home/widgets/product_tabs_block.dart';
import 'package:customer/features/home/widgets/text_section.dart';
import 'package:customer/features/home/widgets/title_image.dart';
import 'package:customer/features/products/models/product_list_scope.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/features/gifting/gift_store.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SectionWidget extends StatelessWidget {
  final Sections section;
  final ValueChanged<Categories>? onCategoryTap;
  final ValueChanged<ProductDataModel>? onProductTap;
  final ValueChanged<Brands>? onBrandTap;
  final ViewMoreTapCallback? onViewMoreTap;

  const SectionWidget({
    super.key,
    required this.section,
    this.onCategoryTap,
    this.onProductTap,
    this.onBrandTap,
    this.onViewMoreTap,
  });

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  // Server sends margin values authored for mobile — double them on tablet
  // so section spacing scales with the larger screen instead of looking
  // cramped relative to it.
  double _scaledMargin(BuildContext context, int? value) =>
      (value ?? 0).toDouble() * (_isTablet(context) ? 2 : 1);

  @override
  Widget build(BuildContext context) {
    final blocks = section.blocks;
    if (blocks == null || blocks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: _scaledMargin(context, section.marginTop),
        bottom: _scaledMargin(context, section.marginBottom),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: blocks.map((block) => _buildBlock(context, block)).toList(),
      ),
    );
  }

  BorderRadius _cornersToBorderRadius(BorderRadiusCorners? corners) {
    return BorderRadius.only(
      topLeft: Radius.circular((corners?.topLeft ?? 0).toDouble()),
      topRight: Radius.circular((corners?.topRight ?? 0).toDouble()),
      bottomLeft: Radius.circular((corners?.bottomLeft ?? 0).toDouble()),
      bottomRight: Radius.circular((corners?.bottomRight ?? 0).toDouble()),
    );
  }

  Widget _buildBlock(BuildContext context, Blocks block) {
    final radius = _cornersToBorderRadius(section.borderRadiusCorners);
    Widget content = _blockContent(context, block);
    if (radius != BorderRadius.zero) {
      content = ClipRRect(borderRadius: radius, child: content);
    }
    return content;
  }

  // Occasion / relationship tile -> product list filtered by that gift filter,
  // the same hand-off the old fixed gift strip used.
  Future<void> _openGift(
    BuildContext context,
    String filterKey,
    Categories item,
  ) async {
    final slug = item.slug;
    if (slug == null || slug.isEmpty) return;
    final store = GiftStore.instance;
    store.activeFilter
      ..clear()
      ..[filterKey] = slug;
    final title = filterKey == 'relationship'
        ? 'Gifts for ${item.name ?? ''}'
        : (item.name ?? '');
    await AppNavigator.push(
      context,
      BlocProvider(
        create: (_) => ProductCubit(),
        child: ProductScreen(title: title),
      ),
    );
    store.activeFilter.clear();
  }

  int _gridColumns(BuildContext context, Blocks block, {int fallback = 2}) {
    final configColumns = block.config?.columns?.resolve(_isTablet(context));
    if (configColumns != null && configColumns > 0) return configColumns;
    final match = RegExp(r'grid_(\d+)').firstMatch(block.layout ?? '');
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return fallback;
  }

  Widget _blockContent(BuildContext context, Blocks block) {
    final isTablet = _isTablet(context);
    switch (BlockType.fromRaw(block.type)) {
      case BlockType.bannerSlider:
        if (block.items?.isNotEmpty == true) {
          return BannerCarousel(
            items: block.items!,
            config: block.config,
            sectionBorderRadius: _cornersToBorderRadius(
              section.borderRadiusCorners,
            ),
          );
        }

      case BlockType.occasionSection:
      case BlockType.relationshipSection:
        if (block.categories?.isNotEmpty == true) {
          final filterKey =
              BlockType.fromRaw(block.type) == BlockType.occasionSection
              ? 'occasion'
              : 'relationship';
          return CategoryBlock(
            categories: block.categories!,
            columns: _gridColumns(context, block, fallback: 4),
            gap: (block.config?.chipGap?.resolve(isTablet) ?? 0).toDouble(),
            borderRadius: (block.config?.chipRadius?.resolve(isTablet) ?? 0)
                .toDouble(),
            layout: SectionLayout.fromRaw(block.layout),
            sectionTitle: block.config?.sectionTitle,
            variant: ProductVariant.fromRaw(block.config?.variant),
            backgroundImageUrl: block.config?.backgroundImageUrl,
            backgroundColor: block.config?.backgroundColor,
            textColor: block.config?.textColor,
            itemTextColor: block.config?.itemTextColor,
            bgImageAspect: block.config?.bgImageAspect?.resolve(isTablet),
            onTap: (item) => _openGift(context, filterKey, item),
          );
        }

      case BlockType.categorySection:
        if (block.categories?.isNotEmpty == true) {
          return CategoryBlock(
            categories: block.categories!,
            columns: _gridColumns(context, block, fallback: 4),
            gap: (block.config?.chipGap?.resolve(isTablet) ?? 0).toDouble(),
            borderRadius: (block.config?.chipRadius?.resolve(isTablet) ?? 0)
                .toDouble(),
            layout: SectionLayout.fromRaw(block.layout),
            sectionTitle: block.config?.sectionTitle,
            variant: ProductVariant.fromRaw(block.config?.variant),
            backgroundImageUrl: block.config?.backgroundImageUrl,
            backgroundColor: block.config?.backgroundColor,
            textColor: block.config?.textColor,
            itemTextColor: block.config?.itemTextColor,
            bgImageAspect: block.config?.bgImageAspect?.resolve(isTablet),
            onTap: onCategoryTap,
          );
        }

      case BlockType.productSlider:
        if (block.products?.isNotEmpty == true) {
          return ProductBlock(
            products: block.products!,
            columns: block.config?.columns?.resolve(isTablet) ?? 2,
            layout: ProductLayout.fromRaw(block.layout),
            variant: ProductVariant.fromRaw(block.config?.variant),
            backgroundImageUrl: block.config?.backgroundImageUrl,
            backgroundColor: block.config?.backgroundColor,
            textColor: block.config?.textColor,
            imageAspect: block.config?.imageAspect?.resolve(isTablet),
            sectionTitle: block.config?.sectionTitle,
            blockPadding: block.config?.blockPadding ?? 0,
            itemGap: block.config?.productGridGap?.resolve(isTablet) ?? 0,
            itemRadius: block.config?.productCardRadius ?? 0,
            limit: block.config?.limit ?? 0,
            onTap: onProductTap,
            blockId: block.id ?? '',
            // category_ids/brand_ids/filter_mode scope the row for every
            // data source, not just "category"/"brand" — pass them through
            // as received. Legacy category_id kept for older responses.
            viewMoreScope: ProductListScope(
              dataSource: block.config?.dataSource,
              categoryIds: block.categoryIds ?? block.categoryId?.toString(),
              brandIds: block.brandIds,
              filterMode: block.filterMode,
              manualProductIds: block.manualProductIds,
            ),
            onViewMoreTap: onViewMoreTap,
            viewMorePreviewImages: block.viewMorePreviewImages,
          );
        }

      case BlockType.brandSection:
        if (block.brands?.isNotEmpty == true) {
          return BrandBlock(
            brands: block.brands!,
            gap: (block.config?.brandGap?.resolve(isTablet) ?? 0).toDouble(),
            layout: SectionLayout.fromRaw(block.layout),
            columns: _gridColumns(context, block, fallback: 4),
            sectionTitle: block.config?.sectionTitle,
            borderRadius: (block.config?.brandRadius?.resolve(isTablet) ?? 0)
                .toDouble(),
            showName: block.config?.showName,
            variant: ProductVariant.fromRaw(block.config?.variant),
            backgroundImageUrl: block.config?.backgroundImageUrl,
            backgroundColor: block.config?.backgroundColor,
            textColor: block.config?.textColor,
            itemTextColor: block.config?.itemTextColor,
            bgImageAspect: block.config?.bgImageAspect?.resolve(isTablet),
            onTap: onBrandTap,
          );
        }

      case BlockType.gridBanner:
        if (block.items?.isNotEmpty == true) {
          return GridBanner(
            items: block.items!,
            columns: _gridColumns(context, block, fallback: 2),
            rows: block.config?.gridRows?.resolve(isTablet) ?? 1,
            layoutType: GridLayoutType.fromRaw(block.config?.gridLayoutType),
            gap: block.config?.gridGap?.resolve(isTablet) ?? 0,
            borderRadius: block.config?.tileRadius ?? 0,
            imageAspect: block.config?.imageAspect?.resolve(isTablet),
            variant: ProductVariant.fromRaw(block.config?.variant),
            backgroundImageUrl: block.config?.backgroundImageUrl,
            backgroundColor: block.config?.backgroundColor,
            textColor: block.config?.textColor,
            sectionTitle: block.config?.sectionTitle,
            bgImageAspect: block.config?.bgImageAspect?.resolve(isTablet),
            blockPadding: block.config?.blockPadding ?? 0,
          );
        }

      case BlockType.titleImage:
        return TitleImage(block: block);

      case BlockType.textSection:
        return TextSection(block: block);

      case BlockType.productTabs:
        if (block.tabs?.isNotEmpty == true) {
          return ProductTabsBlock(
            tabs: block.tabs!,
            columns: block.config?.columns?.resolve(isTablet) ?? 2,
            layout: ProductLayout.fromRaw(block.layout),
            variant: ProductVariant.fromRaw(block.config?.variant),
            backgroundImageUrl: block.config?.backgroundImageUrl,
            backgroundColor: block.config?.backgroundColor,
            textColor: block.config?.textColor,
            imageAspect: block.config?.imageAspect?.resolve(isTablet),
            sectionTitle: block.config?.sectionTitle,
            sectionSubtitle: block.config?.sectionSubtitle,
            blockPadding: block.config?.blockPadding ?? 0,
            itemGap: block.config?.productGridGap?.resolve(isTablet) ?? 0,
            itemRadius: block.config?.productCardRadius ?? 0,
            defaultLimit: block.config?.limit ?? 0,
            tabStyle: TabStyle.fromRaw(block.config?.tabStyle),
            tabImageAspect: block.config?.tabImageAspect?.resolve(isTablet),
            activeTabColor: block.config?.activeTabColor.toColor(),
            tabTextColor: block.config?.tabTextColor.toColor(),
            activeTabTextColor: block.config?.activeTabTextColor.toColor(),
            activeIndicator:
                block.config?.activeIndicator ?? TabActiveIndicator.underline,
            activeBgStyle:
                block.config?.activeBgStyle ?? TabActiveBgStyle.solid,
            activeTabColor2: block.config?.activeTabColor2.toColor(),
            activeOutlineColor: block.config?.activeOutlineColor.toColor(),
            activeBgImageUrl: block.config?.activeBgImageUrl?.resolve(isTablet),
            activeBgImageAspect: block.config?.activeBgImageAspect?.resolve(
              isTablet,
            ),
            tabAnimation: block.config?.tabAnimation ?? TabAnimation.slide,
            onTap: onProductTap,
            blockId: block.id ?? '',
            onViewMoreTap: onViewMoreTap,
          );
        }

      case BlockType.unknown:
        break;
    }

    return const SizedBox.shrink();
  }
}
