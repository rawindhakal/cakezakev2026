import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  // Arbitrary widget to render in the title slot instead of [title]
  // (e.g. an inline search bar). Takes precedence over title/subtitle/search.
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  // Search support
  final bool isSearching;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final VoidCallback? onSearchStart;
  final VoidCallback? onSearchCancel;
  // When true, the search field shows a back-arrow button at its start that
  // cancels search (matches deliveryboy's search app bar); the trailing
  // search/close icon toggle is skipped so there's only one cancel control.
  // Defaults to false so other screens keep their existing behavior.
  final bool inlineSearchCancel;
  // Extra bottom row (e.g. status chips)
  final PreferredSizeWidget? bottom;
  // When provided, the app bar shows a shadow only once the attached
  // scrollable has scrolled content under it (offset > 0), and stays
  // flat while the list sits at rest — keeps the bar visually distinct
  // from cards once they touch it, without a shadow when there's still
  // a gap.
  final ScrollController? scrollController;
  // Alternative to [scrollController] for screens where the scrollable
  // isn't a single ScrollController the app bar can listen to directly
  // (e.g. multiple tabs, each with their own controller) — the caller
  // drives the shadow by pushing true/false into this instead.
  final ValueListenable<bool>? shadowListenable;
  // With [scrollController]: suppress the shadow once offset passes this value
  // (e.g. a StickyBar docked under the app bar casts its own shadow).
  final double? hideShadowAfter;

  const CustomAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isSearching = false,
    this.searchController,
    this.onSearchChanged,
    this.searchHint,
    this.onSearchStart,
    this.onSearchCancel,
    this.inlineSearchCancel = false,
    this.bottom,
    this.scrollController,
    this.shadowListenable,
    this.hideShadowAfter,
  });

  bool get _hasSearch => onSearchStart != null;

  @override
  Size get preferredSize => Size.fromHeight(
    (subtitle != null ? kToolbarHeight + 20 : kToolbarHeight) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    if (shadowListenable != null) {
      return ValueListenableBuilder<bool>(
        valueListenable: shadowListenable!,
        builder: (context, scrolled, _) => _build(context, scrolled: scrolled),
      );
    }
    if (scrollController != null) {
      return AnimatedBuilder(
        animation: scrollController!,
        builder: (context, _) {
          final offset = scrollController!.hasClients
              ? scrollController!.offset
              : 0.0;
          final scrolled =
              offset > 0 &&
              (hideShadowAfter == null || offset <= hideShadowAfter!);
          return _build(context, scrolled: scrolled);
        },
      );
    }
    return _build(context, scrolled: false);
  }

  Widget _build(BuildContext context, {required bool scrolled}) {
    final titleColor = foregroundColor ?? context.cs.onSurface;

    return AppBar(
      backgroundColor: backgroundColor ?? context.cs.surface,
      foregroundColor: titleColor,
      elevation: scrolled ? 4 : 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: scrolled
          ? Colors.black.withValues(alpha: 0.15)
          : Colors.transparent,
      centerTitle: false, //!isSearching,
      titleSpacing: titleWidget != null
          ? 0
          : _hasSearch && isSearching
          ? 16
          : NavigationToolbar.kMiddleSpacing,
      toolbarHeight: subtitle != null ? kToolbarHeight + 20 : kToolbarHeight,
      automaticallyImplyLeading:
          showBackButton && !(inlineSearchCancel && isSearching),
      title:
          titleWidget ??
          (subtitle != null
              ? Column(
                  crossAxisAlignment: .start,
                  mainAxisAlignment: .center,
                  children: [
                    AppText(
                      title ?? '',
                      style: context.tt.titleLarge?.copyWith(color: titleColor),
                    ),
                    AppText(
                      subtitle!,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : _hasSearch
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.92,
                        end: 1.0,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: isSearching
                      ? _AppBarSearchField(
                          key: const ValueKey('search'),
                          controller: searchController!,
                          hint:
                              searchHint ??
                              context.translate(LanguageLabelKeys.search),
                          onChanged: onSearchChanged ?? (_) {},
                          onCancel: inlineSearchCancel ? onSearchCancel : null,
                        )
                      : AppText(
                          title ?? '',
                          key: const ValueKey('title'),
                          style: context.tt.titleLarge?.copyWith(
                            color: titleColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                )
              : title != null
              ? AppText(
                  title!,
                  style: context.tt.titleLarge?.copyWith(color: titleColor),
                )
              : null),
      leading: showBackButton && !(inlineSearchCancel && isSearching)
          ? IconButton(
              icon: Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: AppSvgIcon(
                  AssetsConstants.arrowLeftIcon,
                  size: ThemeConstants.iconL,
                  color: titleColor,
                  bakeTint: true,
                ),
              ),
              onPressed: onBackPressed ?? () => AppNavigator.pop(context),
            )
          : null,
      actions: [
        if (_hasSearch && inlineSearchCancel && !isSearching)
          IconButton(
            key: const ValueKey('searchBtn'),
            icon: AppSvgIcon(
              AssetsConstants.searchIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurfaceVariant,
              bakeTint: true,
            ),
            onPressed: onSearchStart,
            color: context.cs.onSurfaceVariant,
          ),
        if (_hasSearch && !inlineSearchCancel)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isSearching
                ? IconButton(
                    key: const ValueKey('close'),
                    icon: AppSvgIcon(
                      AssetsConstants.closeIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.onSurfaceVariant,
                      bakeTint: true,
                    ),
                    onPressed: onSearchCancel,
                    color: context.cs.onSurfaceVariant,
                  )
                : IconButton(
                    key: const ValueKey('searchBtn'),
                    icon: AppSvgIcon(
                      AssetsConstants.searchIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.onSurfaceVariant,
                      bakeTint: true,
                    ),
                    onPressed: onSearchStart,
                    color: context.cs.onSurfaceVariant,
                  ),
          ),
        ...?actions,
      ],
      bottom: bottom,
    );
  }
}

class _AppBarSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCancel;

  const _AppBarSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final borders = AppDecorations.inputBorderSet(context.cs);
        return Container(
          height: 40,
          decoration: AppDecorations.box(
            color: context.cs.surface,
            borderRadius: AppRadius.r10,
            border: Border.fromBorderSide(borders.enabledBorder.borderSide),
          ),
          child: Row(
            children: [
              if (onCancel != null)
                InkWell(
                  key: const ValueKey('searchCancel'),
                  onTap: onCancel,
                  borderRadius: AppRadius.r10,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingS,
                    ),
                    child: Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: AppSvgIcon(
                        AssetsConstants.arrowLeftIcon,
                        size: ThemeConstants.iconS,
                        color: context.cs.onSurfaceVariant,
                        bakeTint: true,
                      ),
                    ),
                  ),
                )
              else ...[
                AppSpacing.w12,
                AppSvgIcon(
                  AssetsConstants.searchIcon,
                  size: ThemeConstants.iconS,
                  color: context.cs.onSurfaceVariant,
                  bakeTint: true,
                ),
              ],
              AppSpacing.w8,
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsetsDirectional.zero,
                  ),
                ),
              ),
              if (value.text.trim().isNotEmpty)
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(
                      ThemeConstants.paddingS,
                    ),
                    child: AppSvgIcon(
                      AssetsConstants.closeCircleIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.onSurfaceVariant,
                      bakeTint: true,
                    ),
                  ),
                )
              else
                AppSpacing.w12,
            ],
          ),
        );
      },
    );
  }
}
