import 'package:customer/features/home/models/enums/tab_style.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/json_parsers.dart';

/// A value that may differ per device — API sends either a plain scalar
/// (applies to every device) or an object with app/tablet/web keys.
class ResponsiveValue<T> {
  T? app;
  T? tablet;
  T? web;

  ResponsiveValue({this.app, this.tablet, this.web});

  T? resolve(bool isTablet) =>
      isTablet ? (tablet ?? app ?? web) : (app ?? tablet ?? web);

  Map<String, dynamic> toJson() => {'app': app, 'tablet': tablet, 'web': web};
}

ResponsiveValue<int>? _parseResponsiveInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return ResponsiveValue<int>(
      app: parseInt(raw['app']),
      tablet: parseInt(raw['tablet']),
      web: parseInt(raw['web']),
    );
  }
  final v = parseInt(raw);
  return v == null ? null : ResponsiveValue<int>(app: v, tablet: v, web: v);
}

// A blank string in one device slot means "not set" for that device, not
// "set to blank" — treat it as null so resolve() falls back to the other
// device slots instead of returning an empty value.
String? _nonEmptyString(dynamic raw) {
  final v = parseString(raw);
  return v == null || v.isEmpty ? null : v;
}

/// redirect_params: flat query map for customer/products, sent as it comes.
/// An all-blank set may arrive as `{}` or (PHP) `[]` — both mean no filters.
Map<String, String> _parseRedirectParams(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.value != null && e.value.toString().isNotEmpty)
        e.key.toString(): e.value.toString(),
  };
}

ResponsiveValue<String>? _parseResponsiveString(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return ResponsiveValue<String>(
      app: _nonEmptyString(raw['app']),
      tablet: _nonEmptyString(raw['tablet']),
      web: _nonEmptyString(raw['web']),
    );
  }
  final v = _nonEmptyString(raw);
  return v == null ? null : ResponsiveValue<String>(app: v, tablet: v, web: v);
}

class HomeBuilderModel {
  int? status;
  String? message;
  HomeBuilderDataModel? data;

  HomeBuilderModel({this.status, this.message, this.data});

  HomeBuilderModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? HomeBuilderDataModel.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class HomeBuilderDataModel {
  Layout? layout;
  String? homeType;
  String? homeLayoutName;
  List<CategoryTabs>? categoryTabs;
  int? zoneId;
  String? timeToDeliver;
  String? distance;
  String? availableModes;
  String? layoutMode;
  String? quickButtonLabel;
  String? ecommerceButtonLabel;
  List<String>? searchSuggestions;
  int? branchClosed;
  int? totalSections;

  HomeBuilderDataModel({
    this.layout,
    this.homeType,
    this.homeLayoutName,
    this.categoryTabs,
    this.zoneId,
    this.timeToDeliver,
    this.distance,
    this.availableModes,
    this.layoutMode,
    this.quickButtonLabel,
    this.ecommerceButtonLabel,
    this.searchSuggestions,
    this.branchClosed,
    this.totalSections,
  });

  HomeBuilderDataModel.fromJson(Map<String, dynamic> json) {
    layout = json['layout'] is Map<String, dynamic>
        ? Layout.fromJson(json['layout'] as Map<String, dynamic>)
        : null;
    homeType = parseString(json['home_type']);
    homeLayoutName = parseString(json['home_layout_name']);
    final rawCategoryTabs = json['category_tabs'];
    if (rawCategoryTabs is List) {
      categoryTabs = rawCategoryTabs
          .map((v) => CategoryTabs.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    zoneId = parseInt(json['zone_id']);
    timeToDeliver = parseString(json['time_to_deliver']);
    distance = parseString(json['distance']);
    availableModes = parseString(json['available_modes']);
    layoutMode = parseString(json['layout_mode']);
    quickButtonLabel = parseString(json['quick_button_label']);
    ecommerceButtonLabel = parseString(json['ecommerce_button_label']);
    searchSuggestions = json['search_suggestions'] is List
        ? (json['search_suggestions'] as List).map((e) => e.toString()).toList()
        : <String>[];
    branchClosed = parseInt(json['branch_closed']);
    totalSections = parseInt(json['total_sections']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (layout != null) {
      data['layout'] = layout!.toJson();
    }
    data['home_type'] = homeType;
    data['home_layout_name'] = homeLayoutName;
    if (categoryTabs != null) {
      data['category_tabs'] = categoryTabs!.map((v) => v.toJson()).toList();
    }
    data['zone_id'] = zoneId;
    data['time_to_deliver'] = timeToDeliver;
    data['distance'] = distance;
    data['available_modes'] = availableModes;
    data['layout_mode'] = layoutMode;
    data['quick_button_label'] = quickButtonLabel;
    data['ecommerce_button_label'] = ecommerceButtonLabel;
    data['search_suggestions'] = searchSuggestions;
    data['branch_closed'] = branchClosed;
    data['total_sections'] = totalSections;
    return data;
  }
}

class Layout {
  List<Sections>? sections;
  String? backgroundTheme;
  String? backgroundColor;
  String? backgroundImageUrl;
  String? textColor;
  String? headerIconUrl;
  ResponsiveValue<String>? imageAspect;

  Layout({
    this.sections,
    this.backgroundTheme,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.textColor,
    this.headerIconUrl,
    this.imageAspect,
  });

  Layout.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    if (rawSections is List) {
      sections = rawSections
          .map((v) => Sections.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    backgroundTheme = parseString(json['background_theme']);
    backgroundColor = parseString(json['background_color']);
    backgroundImageUrl = json['background_image_url'] is Map<String, dynamic>
        ? Images.fromJson(
            json['background_image_url'] as Map<String, dynamic>,
          ).displayUrl
        : parseString(json['background_image_url']);
    textColor = parseString(json['text_color']);
    headerIconUrl = parseString(json['header_icon_url']);
    imageAspect = _parseResponsiveString(json['image_aspect']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (sections != null) {
      data['sections'] = sections!.map((v) => v.toJson()).toList();
    }
    data['background_theme'] = backgroundTheme;
    data['background_color'] = backgroundColor;
    data['background_image_url'] = backgroundImageUrl;
    data['text_color'] = textColor;
    data['header_icon_url'] = headerIconUrl;
    if (imageAspect != null) {
      data['image_aspect'] = imageAspect!.toJson();
    }
    return data;
  }
}

class Sections {
  String? id;
  String? type;
  int? marginTop;
  int? marginBottom;
  BorderRadiusCorners? borderRadiusCorners;
  List<Blocks>? blocks;

  Sections({
    this.id,
    this.type,
    this.marginTop,
    this.marginBottom,
    this.borderRadiusCorners,
    this.blocks,
  });

  Sections.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']);
    type = parseString(json['type']);
    marginTop = parseInt(json['margin_top']);
    marginBottom = parseInt(json['margin_bottom']);
    borderRadiusCorners = json['border_radius_corners'] is Map<String, dynamic>
        ? BorderRadiusCorners.fromJson(
            json['border_radius_corners'] as Map<String, dynamic>,
          )
        : null;
    final rawBlocks = json['blocks'];
    if (rawBlocks is List) {
      blocks = rawBlocks
          .map((v) => Blocks.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    data['margin_top'] = marginTop;
    data['margin_bottom'] = marginBottom;
    if (borderRadiusCorners != null) {
      data['border_radius_corners'] = borderRadiusCorners!.toJson();
    }
    if (blocks != null) {
      data['blocks'] = blocks!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BorderRadiusCorners {
  int? topLeft;
  int? topRight;
  int? bottomLeft;
  int? bottomRight;

  BorderRadiusCorners({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
  });

  BorderRadiusCorners.fromJson(Map<String, dynamic> json) {
    topLeft = parseInt(json['top_left']);
    topRight = parseInt(json['top_right']);
    bottomLeft = parseInt(json['bottom_left']);
    bottomRight = parseInt(json['bottom_right']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['top_left'] = topLeft;
    data['top_right'] = topRight;
    data['bottom_left'] = bottomLeft;
    data['bottom_right'] = bottomRight;
    return data;
  }
}

class Blocks {
  String? id;
  String? type;
  Config? config;
  List<Items>? items;
  String? layout;
  List<Categories>? categories;
  List<ProductDataModel>? products;
  List<Brands>? brands;
  String? imageUrl;
  Images? images;
  String? redirectType;
  int? redirectId;
  String? redirectUrl;
  String? redirectSlug;
  // redirect_type "products" only: app-bar heading (may be empty) and the
  // product-list query map.
  String? redirectTitle;
  Map<String, String> redirectParams = const {};
  bool? hasChild;
  String? manualProductIds;
  int? categoryId;
  // Row scope for product_slider (any data source): comma-separated ids,
  // category list already includes children. filterMode "exclude" flips it.
  String? categoryIds;
  String? brandIds;
  String? filterMode;
  List<String>? viewMorePreviewImages;
  List<ProductTabsData>? tabs;

  Blocks({
    this.id,
    this.type,
    this.config,
    this.items,
    this.layout,
    this.categories,
    this.products,
    this.brands,
    this.imageUrl,
    this.images,
    this.redirectType,
    this.redirectId,
    this.redirectUrl,
    this.redirectSlug,
    this.hasChild,
    this.manualProductIds,
    this.categoryId,
    this.categoryIds,
    this.brandIds,
    this.filterMode,
    this.viewMorePreviewImages,
    this.tabs,
  });

  Blocks.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']);
    type = parseString(json['type']);
    config = json['config'] is Map<String, dynamic>
        ? Config.fromJson(json['config'] as Map<String, dynamic>)
        : null;
    final rawItems = json['items'];
    if (rawItems is List) {
      items = rawItems
          .map((v) => Items.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    layout = parseString(json['layout']);
    final rawCategories = json['categories'];
    if (rawCategories is List) {
      categories = rawCategories
          .map((v) => Categories.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    // Occasion / relationship showcases ship as their own lists but render
    // through the category tile layout, so they share the Categories shape.
    for (final key in const ['occasions', 'relationships']) {
      final raw = json[key];
      if (raw is List && categories == null) {
        categories = raw
            .map((v) => Categories.fromJson(v as Map<String, dynamic>))
            .toList();
      }
    }
    final rawProducts = json['products'];
    if (rawProducts is List) {
      products = rawProducts
          .map((v) => ProductDataModel.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawBrands = json['brands'];
    if (rawBrands is List) {
      brands = rawBrands
          .map((v) => Brands.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    imageUrl = parseString(json['image_url']);
    images = json['images'] is Map<String, dynamic>
        ? Images.fromJson(json['images'] as Map<String, dynamic>)
        : null;
    redirectType = parseString(json['redirect_type']);
    redirectId = parseInt(json['redirect_id']);
    redirectUrl = parseString(json['redirect_url']);
    redirectSlug = parseString(json['redirect_slug']);
    redirectTitle = _nonEmptyString(json['redirect_title']);
    redirectParams = _parseRedirectParams(json['redirect_params']);
    hasChild = parseBool(json['has_child']) ?? false;
    manualProductIds = parseString(json['manual_product_ids']) ?? "";
    categoryId = parseInt(json['category_id']) ?? 0;
    categoryIds = _nonEmptyString(json['category_ids']);
    brandIds = _nonEmptyString(json['brand_ids']);
    filterMode = _nonEmptyString(json['filter_mode']);
    viewMorePreviewImages = json['viewMorePreviewImages'] is List
        ? (json['viewMorePreviewImages'] as List)
              .map((e) => e.toString())
              .toList()
        : <String>[];
    final rawTabs = json['tabs'];
    if (rawTabs is List) {
      tabs = rawTabs
          .map((v) => ProductTabsData.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    if (config != null) {
      data['config'] = config!.toJson();
    }
    if (items != null) {
      data['items'] = items!.map((v) => v.toJson()).toList();
    }
    data['layout'] = layout;
    if (categories != null) {
      data['categories'] = categories!.map((v) => v.toJson()).toList();
    }
    if (products != null) {
      data['products'] = products!.map((v) => v.toJson()).toList();
    }
    if (brands != null) {
      data['brands'] = brands!.map((v) => v.toJson()).toList();
    }
    data['image_url'] = imageUrl;
    if (images != null) {
      data['images'] = images!.toJson();
    }
    data['redirect_type'] = redirectType;
    data['redirect_id'] = redirectId;
    data['redirect_url'] = redirectUrl;
    data['redirect_slug'] = redirectSlug;
    data['redirect_title'] = redirectTitle;
    data['redirect_params'] = redirectParams;
    data['manual_product_ids'] = manualProductIds;
    data['category_id'] = categoryId;
    data['category_ids'] = categoryIds;
    data['brand_ids'] = brandIds;
    data['filter_mode'] = filterMode;
    data['viewMorePreviewImages'] = viewMorePreviewImages;
    if (tabs != null) {
      data['tabs'] = tabs!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Config {
  String? carouselStyle;
  String? indicator;
  bool? autoScroll;
  bool? infiniteLoop;
  int? speedMs;
  ResponsiveValue<int>? chipGap;
  ResponsiveValue<int>? chipRadius;
  ResponsiveValue<int>? brandGap;
  String? variant;
  String? sectionTitle;
  String? dataSource;
  int? limit;
  ResponsiveValue<int>? columns;
  ResponsiveValue<int>? productGridGap;
  int? productCardRadius;
  int? blockPadding;
  String? backgroundImageUrl;
  bool? showName;
  ResponsiveValue<int>? gridGap;
  int? tileRadius;
  String? textAlign;
  String? textColor;
  String? backgroundColor;
  String? sectionSubtitle;
  int? imageHeight;
  ResponsiveValue<int>? brandRadius;
  ResponsiveValue<int>? gridRows;
  String? gridLayoutType;
  ResponsiveValue<String>? imageAspect;
  ResponsiveValue<String>? bgImageAspect;
  String? itemTextColor;
  String? tabStyle;
  ResponsiveValue<String>? tabImageAspect;
  String? activeTabColor;
  String? tabTextColor;
  String? activeTabTextColor;
  TabActiveIndicator? activeIndicator;
  TabActiveBgStyle? activeBgStyle;
  String? activeTabColor2;
  String? activeOutlineColor;
  ResponsiveValue<String>? activeBgImageUrl;
  ResponsiveValue<String>? activeBgImageAspect;
  TabAnimation? tabAnimation;

  Config({
    this.carouselStyle,
    this.indicator,
    this.autoScroll,
    this.infiniteLoop,
    this.speedMs,
    this.chipGap,
    this.chipRadius,
    this.brandGap,
    this.variant,
    this.sectionTitle,
    this.dataSource,
    this.limit,
    this.columns,
    this.productGridGap,
    this.productCardRadius,
    this.blockPadding,
    this.backgroundImageUrl,
    this.showName,
    this.gridGap,
    this.tileRadius,
    this.textAlign,
    this.textColor,
    this.backgroundColor,
    this.sectionSubtitle,
    this.imageHeight,
    this.brandRadius,
    this.gridRows,
    this.gridLayoutType,
    this.imageAspect,
    this.bgImageAspect,
    this.itemTextColor,
    this.tabStyle,
    this.tabImageAspect,
    this.activeTabColor,
    this.tabTextColor,
    this.activeTabTextColor,
    this.activeIndicator,
    this.activeBgStyle,
    this.activeTabColor2,
    this.activeOutlineColor,
    this.activeBgImageUrl,
    this.activeBgImageAspect,
    this.tabAnimation,
  });

  Config.fromJson(Map<String, dynamic> json) {
    carouselStyle = parseString(json['carousel_style']);
    indicator = parseString(json['indicator']);
    autoScroll = parseBool(json['auto_scroll']);
    infiniteLoop = parseBool(json['infinite_loop']);
    speedMs = parseInt(json['speed_ms']);
    chipGap = _parseResponsiveInt(json['category_gap'] ?? json['chip_gap']);
    chipRadius = _parseResponsiveInt(
      json['category_radius'] ?? json['chip_radius'],
    );
    brandGap = _parseResponsiveInt(json['brand_gap']);
    variant = parseString(json['variant']);
    sectionTitle = parseString(json['section_title']);
    dataSource = parseString(json['data_source']);
    limit = parseInt(json['limit']);
    columns = _parseResponsiveInt(json['grid_columns'] ?? json['columns']);
    productGridGap = _parseResponsiveInt(json['product_grid_gap']);
    productCardRadius = parseInt(json['product_card_radius']);
    blockPadding = parseInt(json['block_padding']);
    backgroundImageUrl = json['background_image_url'] is Map<String, dynamic>
        ? Images.fromJson(
            json['background_image_url'] as Map<String, dynamic>,
          ).displayUrl
        : parseString(json['background_image_url']);
    showName = parseBool(json['show_name']);
    gridGap = _parseResponsiveInt(json['grid_gap']);
    tileRadius = parseInt(json['tile_radius']);
    textAlign = parseString(json['text_align']);
    textColor = parseString(json['text_color']);
    backgroundColor = parseString(json['background_color']);
    sectionSubtitle = parseString(json['section_subtitle']);
    imageHeight = parseInt(json['image_height']);
    brandRadius = _parseResponsiveInt(json['brand_radius']);
    gridRows = _parseResponsiveInt(json['grid_rows']);
    gridLayoutType = parseString(json['grid_layout_type']);
    imageAspect = _parseResponsiveString(json['image_aspect']);
    bgImageAspect = _parseResponsiveString(json['bg_image_aspect']);
    itemTextColor = parseString(json['item_text_color']) ?? "";
    tabStyle = parseString(json['tab_style']);
    tabImageAspect = _parseResponsiveString(json['tab_image_aspect']);
    activeTabColor = parseString(json['active_tab_color']);
    tabTextColor = parseString(json['tab_text_color']);
    activeTabTextColor = parseString(json['active_tab_text_color']);
    activeIndicator = TabActiveIndicator.fromRaw(
      parseString(json['active_indicator']),
    );
    activeBgStyle = TabActiveBgStyle.fromRaw(
      parseString(json['active_bg_style']),
    );
    activeTabColor2 = parseString(json['active_tab_color_2']);
    activeOutlineColor = parseString(json['active_outline_color']);
    activeBgImageUrl = _parseResponsiveString(json['active_bg_image_url']);
    activeBgImageAspect = _parseResponsiveString(
      json['active_bg_image_aspect'],
    );
    tabAnimation = TabAnimation.fromRaw(parseString(json['tab_animation']));
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['carousel_style'] = carouselStyle;
    data['indicator'] = indicator;
    data['auto_scroll'] = autoScroll;
    data['infinite_loop'] = infiniteLoop;
    data['speed_ms'] = speedMs;
    data['category_gap'] = chipGap?.toJson();
    data['category_radius'] = chipRadius?.toJson();
    data['brand_gap'] = brandGap?.toJson();
    data['variant'] = variant;
    data['section_title'] = sectionTitle;
    data['data_source'] = dataSource;
    data['limit'] = limit;
    data['grid_columns'] = columns?.toJson();
    data['product_grid_gap'] = productGridGap?.toJson();
    data['product_card_radius'] = productCardRadius;
    data['block_padding'] = blockPadding;
    data['background_image_url'] = backgroundImageUrl;
    data['show_name'] = showName;
    data['grid_gap'] = gridGap?.toJson();
    data['tile_radius'] = tileRadius;
    data['text_align'] = textAlign;
    data['text_color'] = textColor;
    data['background_color'] = backgroundColor;
    data['section_subtitle'] = sectionSubtitle;
    data['image_height'] = imageHeight;
    data['brand_radius'] = brandRadius?.toJson();
    data['grid_rows'] = gridRows?.toJson();
    data['grid_layout_type'] = gridLayoutType;
    data['image_aspect'] = imageAspect?.toJson();
    data['bg_image_aspect'] = bgImageAspect?.toJson();
    data['item_text_color'] = itemTextColor;
    data['tab_style'] = tabStyle;
    data['tab_image_aspect'] = tabImageAspect?.toJson();
    data['active_tab_color'] = activeTabColor;
    data['tab_text_color'] = tabTextColor;
    data['active_tab_text_color'] = activeTabTextColor;
    data['active_indicator'] = activeIndicator?.name;
    data['active_bg_style'] = activeBgStyle?.name;
    data['active_tab_color_2'] = activeTabColor2;
    data['active_outline_color'] = activeOutlineColor;
    data['active_bg_image_url'] = activeBgImageUrl?.toJson();
    data['active_bg_image_aspect'] = activeBgImageAspect?.toJson();
    data['tab_animation'] = tabAnimation?.name;
    return data;
  }
}

class Items {
  String? imageUrl;
  Images? images;
  String? redirectType;
  int? redirectId;
  String? redirectUrl;
  String? redirectSlug;
  String? redirectTitle;
  Map<String, String> redirectParams = const {};
  bool? hasChild;

  Items({
    this.imageUrl,
    this.images,
    this.redirectType,
    this.redirectId,
    this.redirectUrl,
    this.redirectSlug,
    this.hasChild,
  });

  Items.fromJson(Map<String, dynamic> json) {
    imageUrl = parseString(json['image_url']);
    images = json['images'] is Map<String, dynamic>
        ? Images.fromJson(json['images'] as Map<String, dynamic>)
        : null;
    redirectType = parseString(json['redirect_type']);
    redirectId = parseInt(json['redirect_id']);
    redirectUrl = parseString(json['redirect_url']);
    redirectSlug = parseString(json['redirect_slug']);
    redirectTitle = _nonEmptyString(json['redirect_title']);
    redirectParams = _parseRedirectParams(json['redirect_params']);
    hasChild = parseBool(json['has_child']) ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['image_url'] = imageUrl;
    if (images != null) {
      data['images'] = images!.toJson();
    }
    data['redirect_type'] = redirectType;
    data['redirect_id'] = redirectId;
    data['redirect_url'] = redirectUrl;
    data['redirect_slug'] = redirectSlug;
    data['redirect_title'] = redirectTitle;
    data['redirect_params'] = redirectParams;
    return data;
  }
}

class Images {
  String? app;
  String? web;
  String? tablet;
  String? imageUrl;

  Images({this.app, this.web, this.tablet, this.imageUrl});

  Images.fromJson(Map<String, dynamic> json) {
    app = parseString(json['app']);
    web = parseString(json['web']);
    tablet = parseString(json['tablet']);
    imageUrl = parseString(json['image_url']);
  }

  // app -> tablet -> web -> imageUrl, matching ResponsiveValue.resolve's
  // fallback order: previously this skipped `tablet` entirely and checked
  // the generic `imageUrl` before `web`, so an image set only in `tablet`
  // (or only in `web`, with `imageUrl` also blank) never showed up.
  String? get displayUrl => app?.isNotEmpty == true
      ? app
      : tablet?.isNotEmpty == true
      ? tablet
      : web?.isNotEmpty == true
      ? web
      : imageUrl?.isNotEmpty == true
      ? imageUrl
      : null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['app'] = app;
    data['web'] = web;
    data['tablet'] = tablet;
    data['image_url'] = imageUrl;
    return data;
  }
}

class Categories {
  int? id;
  String? name;
  String? slug;
  String? imageUrl;
  bool? hasChild;

  Categories({this.id, this.name, this.slug, this.imageUrl, this.hasChild});

  Categories.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    slug = parseString(json['slug']);
    imageUrl = parseString(json['image_url']);
    hasChild = parseBool(json['has_child']) ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['image_url'] = imageUrl;
    data['has_child'] = hasChild;
    return data;
  }
}

class Brands {
  int? id;
  String? name;
  String? imageUrl;

  Brands({this.id, this.name, this.imageUrl});

  Brands.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    imageUrl = parseString(json['image_url']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image_url'] = imageUrl;
    return data;
  }
}

class ProductTabsData {
  String? id;
  String? title;
  Images? images;
  String? dataSource;
  int? limit;
  List<ProductDataModel>? products;
  List<String>? viewMorePreviewImages;
  // Scope sits on each tab, not the section — two tabs can differ.
  String? categoryIds;
  String? brandIds;
  String? filterMode;

  ProductTabsData({
    this.id,
    this.title,
    this.images,
    this.dataSource,
    this.limit,
    this.products,
    this.viewMorePreviewImages,
    this.categoryIds,
    this.brandIds,
    this.filterMode,
  });

  ProductTabsData.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']);
    title = parseString(json['title']);
    images = json['images'] is Map<String, dynamic>
        ? Images.fromJson(json['images'] as Map<String, dynamic>)
        : null;
    dataSource = parseString(json['data_source']);
    limit = parseInt(json['limit']);
    final rawProducts = json['products'];
    if (rawProducts is List) {
      products = rawProducts
          .map((v) => ProductDataModel.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    viewMorePreviewImages = json['viewMorePreviewImages'] is List
        ? (json['viewMorePreviewImages'] as List)
              .map((e) => e.toString())
              .toList()
        : <String>[];
    categoryIds = _nonEmptyString(json['category_ids']);
    brandIds = _nonEmptyString(json['brand_ids']);
    filterMode = _nonEmptyString(json['filter_mode']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    if (images != null) {
      data['images'] = images!.toJson();
    }
    data['data_source'] = dataSource;
    data['limit'] = limit;
    if (products != null) {
      data['products'] = products!.map((v) => v.toJson()).toList();
    }
    data['viewMorePreviewImages'] = viewMorePreviewImages;
    data['category_ids'] = categoryIds;
    data['brand_ids'] = brandIds;
    data['filter_mode'] = filterMode;
    return data;
  }
}

class CategoryTabs {
  String? id;
  String? name;
  String? backgroundTheme;
  String? backgroundColor;
  String? backgroundImageUrl;
  String? textColor;
  String? headerIconUrl;
  String? imageUrl;
  String? slug;

  CategoryTabs({
    this.id,
    this.name,
    this.backgroundTheme,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.textColor,
    this.headerIconUrl,
    this.imageUrl,
    this.slug,
  });

  CategoryTabs.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']);
    name = parseString(json['name']);
    backgroundTheme = parseString(json['background_theme']);
    backgroundColor = parseString(json['background_color']);
    backgroundImageUrl = json['background_image_url'] is Map<String, dynamic>
        ? Images.fromJson(
            json['background_image_url'] as Map<String, dynamic>,
          ).displayUrl
        : parseString(json['background_image_url']);
    textColor = parseString(json['text_color']);
    headerIconUrl = parseString(json['header_icon_url']);
    imageUrl = parseString(json['image_url']);
    slug = parseString(json['slug']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['background_theme'] = backgroundTheme;
    data['background_color'] = backgroundColor;
    data['background_image_url'] = backgroundImageUrl;
    data['text_color'] = textColor;
    data['header_icon_url'] = headerIconUrl;
    data['image_url'] = imageUrl;
    data['slug'] = slug;
    return data;
  }
}
