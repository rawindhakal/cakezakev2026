import 'dart:async';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/products/cubit/search_product_cubit.dart';
import 'package:customer/features/products/screens/product_search_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class HomeAnimatedGradient extends ImplicitlyAnimatedWidget {
  final List<Color> colors;
  final Widget child;

  const HomeAnimatedGradient({
    super.key,
    required this.colors,
    required this.child,
    super.duration = const Duration(milliseconds: 380),
  }) : super(curve: Curves.easeInOut);

  @override
  ImplicitlyAnimatedWidgetState<HomeAnimatedGradient> createState() =>
      _HomeAnimatedGradientState();
}

class _HomeAnimatedGradientState
    extends AnimatedWidgetBaseState<HomeAnimatedGradient> {
  List<ColorTween?>? _tweens;

  @override
  void forEachTween(TweenVisitor<Object?> visitor) {
    final n = widget.colors.length;
    final next = List<ColorTween?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      next[i] =
          visitor(
                (_tweens != null && i < _tweens!.length) ? _tweens![i] : null,
                widget.colors[i],
                (dynamic v) => ColorTween(begin: v as Color?),
              )
              as ColorTween?;
    }
    _tweens = next;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColors = _tweens!
        .map((t) => t?.evaluate(animation) ?? Colors.transparent)
        .toList();
    return DecoratedBox(
      decoration: AppDecorations.box(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: resolvedColors,
        ),
      ),
      child: widget.child,
    );
  }
}

class HomeModeToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final String? quickLabel;
  final String? ecommerceLabel;

  const HomeModeToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    this.quickLabel,
    this.ecommerceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      quickLabel ?? context.translate(LanguageLabelKeys.filterQuick),
      ecommerceLabel ?? context.translate(LanguageLabelKeys.filterEcommerce),
    ];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = selected == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (!active) AppHaptics.tick();
              onChanged(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: EdgeInsetsDirectional.only(
                end: i == 0 ? ThemeConstants.paddingXS : 0,
                start: i == 1 ? ThemeConstants.paddingXS : 0,
              ),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingM,
                vertical: ThemeConstants.paddingS,
              ),
              decoration: AppDecorations.box(
                color: active
                    ? context.cs.surface
                    : context.cs.scrim.withValues(alpha: 0.15),
                border: active
                    ? null
                    : Border.all(
                        color: context.cs.onPrimary.withValues(alpha: 0.6),
                      ),
                borderRadius: AppRadius.r14,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: context.theme.shadowColor.withValues(
                            alpha: 0.12,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: AppText(
                labels[i],
                style: context.tt.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: active ? context.cs.onSurface : context.cs.onPrimary,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key, this.searchSuggestions});

  final List<String>? searchSuggestions;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  int _hintIndex = 0;
  late final Timer _timer;

  List<String> _hints(BuildContext context) =>
      (widget.searchSuggestions?.isNotEmpty ?? false)
      ? widget.searchSuggestions!
      : const [''];

  String _currentHint(BuildContext context) {
    final hints = _hints(context);
    return hints[_hintIndex % hints.length];
  }

  /// Static "Search" prefix — only the quoted suggestion animates. Empty when
  /// the suggestion is empty, since the fallback hint is a full sentence.
  String _hintPrefix(BuildContext context) => _currentHint(context).isEmpty
      ? ''
      : '${context.translate(LanguageLabelKeys.search)} ';

  String _animatedHint(BuildContext context) {
    final hint = _currentHint(context);
    return hint.isEmpty
        ? context.translate(LanguageLabelKeys.searchProductsHint)
        : '"$hint"';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _hintIndex = (_hintIndex + 1) % _hints(context).length);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchH = context.screenHeight * 0.045;
    final hintStyle = context.tt.bodySmall?.copyWith(
      color: context.cs.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return GestureDetector(
      onTap: () => AppNavigator.push(
        context,
        BlocProvider(
          create: (_) => SearchProductCubit(),
          child: ProductSearchScreen(
            searchSuggestions: widget.searchSuggestions,
          ),
        ),
      ),
      child: Container(
        height: searchH,
        decoration: AppDecorations.box(
          color: context.cs.surface,
          borderRadius: AppRadius.r10,
          boxShadow: [
            BoxShadow(
              color: context.theme.shadowColor.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AppSpacing.w12,
            AppSvgIcon(
              AssetsConstants.searchIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurfaceVariant,
              fit: BoxFit.scaleDown,
            ),
            AppSpacing.w8,
            if (_hintPrefix(context).isNotEmpty)
              AppText(_hintPrefix(context), style: hintStyle, maxLines: 1),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    final isEntering =
                        (child.key as ValueKey<int>).value == _hintIndex;
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: Offset(0, isEntering ? 0.5 : -0.5),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  child: Align(
                    key: ValueKey<int>(_hintIndex),
                    alignment: AlignmentDirectional.centerStart,
                    child: AppText(
                      _animatedHint(context),
                      style: hintStyle,
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingS,
              ),
              color: context.cs.outline,
            ),
            AppSvgIcon(
              AssetsConstants.microphoneIcon,
              color: context.cs.onSurfaceVariant,
              size: ThemeConstants.iconS,
            ),
            AppSpacing.w12,
          ],
        ),
      ),
    );
  }
}

class HomeNavTabBar extends StatelessWidget {
  final List<CategoryTabs> tabs;
  final TabController tabController;
  final Color? textColor;
  final ValueChanged<int>? onTabTap;

  const HomeNavTabBar({
    super.key,
    required this.tabs,
    required this.tabController,
    this.textColor,
    this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor ?? context.cs.onPrimary;
    return TabBar(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      controller: tabController,
      onTap: onTabTap,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: resolvedTextColor,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelColor: resolvedTextColor,
      unselectedLabelColor: resolvedTextColor.withValues(alpha: 0.6),
      padding: EdgeInsetsDirectional.zero,
      labelPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
      ),
      tabs: tabs.asMap().entries.map((e) {
        final sh = context.screenHeight;
        final sw = context.screenWidth;
        final tabIconSize = sw * 0.060;
        final tab = e.value;
        return Tab(
          height: sh * 0.060 + 16,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                AppSpacing.h4,
                Container(
                  width: tabIconSize,
                  height: tabIconSize,
                  decoration: AppDecorations.box(shape: .circle),
                  child: AppNetworkImage(
                    url: tab.headerIconUrl?.isNotEmpty == true
                        ? tab.headerIconUrl!
                        : (tab.imageUrl ?? ''),
                  ),
                  /* ), */
                ),
                AppSpacing.h4,
                AppText(
                  (tab.name?.length ?? 0) > 11
                      ? '${tab.name!.substring(0, 9)}..'
                      : (tab.name ?? ''),
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: resolvedTextColor,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                AppSpacing.h8,
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
