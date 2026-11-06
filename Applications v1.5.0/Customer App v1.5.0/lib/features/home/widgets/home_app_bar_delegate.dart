import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/home_type.dart';
import 'package:customer/features/home/models/enums/background_theme_type.dart';
import 'package:customer/features/home/models/enums/layout_mode_type.dart';
import 'package:customer/features/home/utils/home_hex_color.dart';
import 'package:customer/features/home/widgets/home_app_bar_widgets.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class HomeAppBarDelegate extends SliverPersistentHeaderDelegate {
  final List<Color> gradient;
  final List<CategoryTabs> categoryTabs;
  final CategoryTabs? selectedTab;
  final TabController? tabController;
  final int selectedMode;
  final ValueChanged<int> onModeChanged;
  final double topPadding;
  final String locationLabel;
  final String locationAddress;
  final VoidCallback onLocationTap;
  final String layoutMode;
  final HomeType homeType;
  final Layout? layout;
  final double screenHeight;
  final String? timeToDeliver;
  final String? distance;
  final String? channelLabelQuick;
  final String? channelLabelEcommerce;
  final List<String>? searchSuggestions;
  final ValueChanged<int>? onCategoryTabTap;
  final double textScaleFactor;

  // build() runs on every collapse frame, but only the wrapper (height,
  // opacity, translate) depends on shrinkOffset. Reusing the same child
  // instances lets the framework skip rebuilding the location block, search
  // bar and TabBar each frame. A new delegate is made on every HomeScreen
  // build, so these never go stale.
  Widget? _locationContent;
  Widget? _bottomContent;

  HomeAppBarDelegate({
    required this.gradient,
    required this.categoryTabs,
    this.selectedTab,
    this.tabController,
    required this.selectedMode,
    required this.onModeChanged,
    required this.topPadding,
    required this.locationLabel,
    required this.locationAddress,
    required this.onLocationTap,
    required this.layoutMode,
    required this.homeType,
    this.layout,
    required this.screenHeight,
    this.timeToDeliver,
    this.distance,
    this.channelLabelQuick,
    this.channelLabelEcommerce,
    this.searchSuggestions,
    this.onCategoryTabTap,
    this.textScaleFactor = 1.0,
  });

  // Builds a [light, dark] gradient pair from a single source color by shifting its HSL lightness,
  // so the gradient always derives from the API color instead of introducing a second hardcoded one.
  List<Color> _gradientFrom(Color color) {
    final hsl = HSLColor.fromColor(color);
    final light = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0))
        .toColor();
    return [dark, light];
  }

  Color _contentColor(BuildContext context) {
    if (homeType == HomeType.single) {
      return parseHomeHexColor(layout?.textColor) ?? context.cs.onPrimary;
    }
    return parseHomeHexColor(selectedTab?.textColor) ?? context.cs.onPrimary;
  }

  Widget _wrapBackground(Widget child) {
    if (homeType == HomeType.single) {
      if (BackgroundThemeType.fromRaw(layout?.backgroundTheme) ==
          BackgroundThemeType.image) {
        final url = layout?.backgroundImageUrl;
        if (url != null && url.isNotEmpty) {
          final fallbackColor =
              parseHomeHexColor(layout?.backgroundColor) ?? gradient[0];
          return Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: url,
                fit: BoxFit.contain,
                placeholder: HomeAnimatedGradient(
                  colors: _gradientFrom(fallbackColor),
                  child: const SizedBox.expand(),
                ),
                errorWidget: HomeAnimatedGradient(
                  colors: _gradientFrom(fallbackColor),
                  child: const SizedBox.expand(),
                ),
              ),
              child,
            ],
          );
        }
      }
      if (BackgroundThemeType.fromRaw(layout?.backgroundTheme) ==
          BackgroundThemeType.color) {
        final color = parseHomeHexColor(layout?.backgroundColor);
        if (color != null) {
          return HomeAnimatedGradient(
            colors: _gradientFrom(color),
            child: child,
          );
        }
      }
      return HomeAnimatedGradient(
        colors: _gradientFrom(gradient[0]),
        child: child,
      );
    }

    final tab = selectedTab;
    if (tab != null) {
      if (BackgroundThemeType.fromRaw(tab.backgroundTheme) ==
          BackgroundThemeType.image) {
        final url = tab.backgroundImageUrl;
        if (url != null && url.isNotEmpty) {
          final fallbackColor =
              parseHomeHexColor(tab.backgroundColor) ?? gradient[0];
          return Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                placeholder: HomeAnimatedGradient(
                  colors: _gradientFrom(fallbackColor),
                  child: const SizedBox.expand(),
                ),
                errorWidget: HomeAnimatedGradient(
                  colors: _gradientFrom(fallbackColor),
                  child: const SizedBox.expand(),
                ),
              ),
              child,
            ],
          );
        }
      }
      if (BackgroundThemeType.fromRaw(tab.backgroundTheme) ==
          BackgroundThemeType.color) {
        final color = parseHomeHexColor(tab.backgroundColor);
        if (color != null) {
          return HomeAnimatedGradient(
            colors: _gradientFrom(color),
            child: child,
          );
        }
      }
    }
    return HomeAnimatedGradient(
      colors: _gradientFrom(gradient[0]),
      child: child,
    );
  }

  // clamp so accessibility/tablet text scale doesn't blow the header out — just gives text rows breathing room
  double get _scale => textScaleFactor.clamp(1.0, 1.2);

  // no-tabs: tight to search bar's own height (screenHeight*0.045) + its padding (top 8 + bottom 14)
  double get _searchH => categoryTabs.isEmpty
      ? screenHeight * 0.045 + 22
      : screenHeight * 0.1075 + 40;

  bool get _hasQuickEta =>
      SettingsHiveBox.instance.channel == AppConstants.quick &&
      (timeToDeliver?.isNotEmpty ?? false);

  // extra space for the small "delivery in" label + bigger ETA text when quick channel is active
  // when store is closed the "delivery in" label line is hidden, so less extra space is needed
  // (the big ETA-style text line is still taller than the simple title line, so some extra stays)
  double get _quickEtaExtraH {
    if (!_hasQuickEta) return 0.0;
    return (SettingsHiveBox.instance.isStoreClosedQuick ? 8.0 : 18.0) * _scale;
  }

  // 'both': toggle(40) + spacing(10) + padding(2) = 52px fixed chrome, that doesn't grow with text scale,
  // + the actual label/time/address text block (~44px) which does — scaling the whole 96 flat inflated
  // the header well past what the text needed on tablets with a bumped text scale.
  double get _locationH {
    const chromeH = 52.0;
    const textBlockH = 44.0;
    final base = LayoutModeType.fromRaw(layoutMode) == LayoutModeType.both
        ? chromeH + textBlockH * _scale
        : (screenHeight * 0.06).clamp(40.0, 50.0) * _scale;
    return base + _quickEtaExtraH;
  }

  @override
  double get minExtent => topPadding + _searchH;

  @override
  double get maxExtent => topPadding + _locationH + _searchH;

  @override
  bool shouldRebuild(covariant HomeAppBarDelegate old) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / _locationH).clamp(0.0, 1.0);
    final locationH = _locationH * (1.0 - t);
    final Color contentColor = _contentColor(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: _wrapBackground(
        IconTheme(
          data: IconThemeData(color: contentColor),
          child: DefaultTextStyle(
            style: context.tt.bodyMedium!.copyWith(color: contentColor),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                SizedBox(height: topPadding),
                if (locationH > 0)
                  ClipRect(
                    child: SizedBox(
                      height: locationH,
                      child: Opacity(
                        opacity: (1.0 - t * 2).clamp(0.0, 1.0),
                        child: OverflowBox(
                          maxHeight: double.infinity,
                          alignment: AlignmentDirectional.topStart,
                          // slide the block up with the collapse so it exits under the status bar
                          // edge (like normal scrolling) instead of being cut from the bottom
                          child: Transform.translate(
                            offset: Offset(0, locationH - _locationH),
                            child: _locationContent ??= Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                ThemeConstants.paddingL,
                                ThemeConstants.paddingXS,
                                ThemeConstants.paddingL,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment: .start,
                                mainAxisSize: .min,
                                spacing: ThemeConstants.spaceM,
                                children: [
                                  if (LayoutModeType.fromRaw(layoutMode) ==
                                      LayoutModeType.both)
                                    Center(
                                      child: HomeModeToggle(
                                        selected: selectedMode,
                                        onChanged: onModeChanged,
                                        quickLabel:
                                            channelLabelQuick?.isNotEmpty ==
                                                true
                                            ? channelLabelQuick!
                                            : context.translate(
                                                LanguageLabelKeys.filterQuick,
                                              ),
                                        ecommerceLabel:
                                            channelLabelEcommerce?.isNotEmpty ==
                                                true
                                            ? channelLabelEcommerce!
                                            : context.translate(
                                                LanguageLabelKeys
                                                    .filterEcommerce,
                                              ),
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: .max,
                                    crossAxisAlignment: .center,
                                    spacing: ThemeConstants.spaceS,
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: onLocationTap,
                                          child: Column(
                                            crossAxisAlignment: .start,
                                            mainAxisSize: .min,
                                            children: [
                                              if (SettingsHiveBox
                                                          .instance
                                                          .channel ==
                                                      AppConstants.quick &&
                                                  (timeToDeliver?.isNotEmpty ??
                                                      false)) ...[
                                                if (!SettingsHiveBox
                                                    .instance
                                                    .isStoreClosedQuick)
                                                  AppText(
                                                    context.translate(
                                                      LanguageLabelKeys
                                                          .deliveryIn,
                                                    ),
                                                    style: context.tt.labelSmall
                                                        ?.copyWith(
                                                          color: contentColor
                                                              .withValues(
                                                                alpha: 0.75,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          height: 1.2,
                                                        ),
                                                    maxLines: 1,
                                                    overflow: .ellipsis,
                                                  ),
                                                Row(
                                                  mainAxisSize: .min,
                                                  crossAxisAlignment: .center,
                                                  spacing:
                                                      ThemeConstants.spaceS,
                                                  children: [
                                                    Flexible(
                                                      child: AppText(
                                                        SettingsHiveBox
                                                                .instance
                                                                .isStoreClosedQuick
                                                            ? context.translate(
                                                                LanguageLabelKeys
                                                                    .unavailable,
                                                              )
                                                            : timeToDeliver!,
                                                        style: context
                                                            .tt
                                                            .headlineSmall
                                                            ?.copyWith(
                                                              color:
                                                                  contentColor,
                                                              fontSize: 26,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              height: 1.1,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: .ellipsis,
                                                      ),
                                                    ),
                                                    if (distance != null &&
                                                        !SettingsHiveBox
                                                            .instance
                                                            .isStoreClosedQuick)
                                                      Container(
                                                        padding:
                                                            const EdgeInsetsDirectional.symmetric(
                                                              horizontal:
                                                                  ThemeConstants
                                                                      .paddingS,
                                                              vertical:
                                                                  ThemeConstants
                                                                      .paddingXS,
                                                            ),
                                                        decoration:
                                                            AppDecorations.box(
                                                              color: contentColor
                                                                  .withValues(
                                                                    alpha: 0.18,
                                                                  ),
                                                              borderRadius:
                                                                  AppRadius.r12,
                                                            ),
                                                        child: Row(
                                                          mainAxisSize: .min,
                                                          spacing:
                                                              ThemeConstants
                                                                  .spaceXXS,
                                                          children: [
                                                            AppSvgIcon(
                                                              AssetsConstants
                                                                  .directionsWalkIcon,
                                                              color:
                                                                  contentColor,
                                                              size:
                                                                  ThemeConstants
                                                                      .iconXS,
                                                            ),
                                                            AppText(
                                                              '$distance ${context.translate(LanguageLabelKeys.away)}',
                                                              style: context
                                                                  .tt
                                                                  .labelSmall
                                                                  ?.copyWith(
                                                                    color:
                                                                        contentColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ] else
                                                Row(
                                                  mainAxisSize: .min,
                                                  spacing:
                                                      ThemeConstants.spaceXXS,
                                                  children: [
                                                    Flexible(
                                                      child: AppText(
                                                        locationLabel,
                                                        style: context
                                                            .tt
                                                            .titleLarge
                                                            ?.copyWith(
                                                              color:
                                                                  contentColor,
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              height: 1.2,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: .ellipsis,
                                                      ),
                                                    ),
                                                    AppSvgIcon(
                                                      AssetsConstants
                                                          .arrowDownIcon,
                                                      color: contentColor,
                                                      size:
                                                          ThemeConstants.iconM,
                                                    ),
                                                  ],
                                                ),
                                              if (locationAddress.isNotEmpty)
                                                Row(
                                                  mainAxisSize: .min,
                                                  spacing:
                                                      ThemeConstants.spaceXXS,
                                                  children: [
                                                    Flexible(
                                                      child: AppText(
                                                        locationAddress,
                                                        style: context
                                                            .tt
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color: contentColor
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  ),
                                                              height: 1.4,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: .ellipsis,
                                                      ),
                                                    ),
                                                    if (SettingsHiveBox
                                                                .instance
                                                                .channel ==
                                                            AppConstants
                                                                .quick &&
                                                        (timeToDeliver
                                                                ?.isNotEmpty ??
                                                            false))
                                                      AppSvgIcon(
                                                        AssetsConstants
                                                            .arrowDownIcon,
                                                        color: contentColor
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        size: ThemeConstants
                                                            .iconXS,
                                                      ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => AppNavigator.pushNamed(
                                          context,
                                          RouteNames.notificationList,
                                        ),
                                        child: Container(
                                          padding:
                                              const EdgeInsetsDirectional.all(
                                                ThemeConstants.paddingS,
                                              ),
                                          decoration:
                                              AppDecorations.circleIconBadge(
                                                color: context.cs.surface,
                                              ),
                                          child: AppSvgIcon(
                                            AssetsConstants.notificationIcon,
                                            color: context.cs.onSurface,
                                            size: ThemeConstants.iconM,
                                            fit: BoxFit.scaleDown,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _bottomContent ??= Column(
                    mainAxisAlignment: .end,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingM,
                          ThemeConstants.paddingS,
                          ThemeConstants.paddingM,
                          ThemeConstants.paddingM,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: HomeSearchBar(
                                searchSuggestions: searchSuggestions,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (categoryTabs.isNotEmpty && tabController != null) ...[
                        HomeNavTabBar(
                          tabs: categoryTabs,
                          tabController: tabController!,
                          textColor: contentColor,
                          onTabTap: onCategoryTabTap,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
