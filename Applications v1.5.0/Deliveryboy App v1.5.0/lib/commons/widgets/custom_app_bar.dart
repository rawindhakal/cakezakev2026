import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// App-wide top bar supporting a title, back button, actions, or an inline search field.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  // Optional step progress ring shown at the end of the app bar (e.g. "1/2").
  final int? currentStep;
  final int? totalSteps;
  // Search support
  final bool isSearching;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final VoidCallback? onSearchStart;
  final VoidCallback? onSearchCancel;
  // Defaults to the back arrow (matches leaving-the-screen navigation). Pass
  // [AssetsConstants.closeIcon] on screens where cancelling search dismisses
  // an overlay rather than navigating back, so the icon matches the action.
  final String? searchCancelIcon;
  // Extra bottom row (e.g. status chips)
  final PreferredSizeWidget? bottom;
  // Custom multi-line title content — overrides the plain [title] Text when set.
  final Widget? titleWidget;
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
  // With [scrollController] and [collapseOffset], [collapsedLeading] (e.g. a
  // small avatar) grows in before the title as the offset nears
  // [collapseOffset]; pair with a CollapseOnScroll in the body.
  final double? collapseOffset;
  final Widget? collapsedLeading;

  const CustomAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.currentStep,
    this.totalSteps,
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
    this.searchCancelIcon,
    this.bottom,
    this.titleWidget,
    this.scrollController,
    this.shadowListenable,
    this.collapseOffset,
    this.collapsedLeading,
  });

  bool get _hasSearch => onSearchStart != null;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

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
          final scrolled =
              scrollController!.hasClients && scrollController!.offset > 0;
          final progress = collapseOffset == null
              ? 1.0
              : (scrollController!.hasClients
                        ? scrollController!.offset / collapseOffset!
                        : 0.0)
                    .clamp(0.0, 1.0);
          return _build(context, scrolled: scrolled, progress: progress);
        },
      );
    }
    return _build(context, scrolled: false);
  }

  Widget? _collapsing(double progress, Widget? child) {
    if (collapseOffset == null || collapsedLeading == null || child == null) {
      return child;
    }
    return Row(
      children: [
        ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: progress,
            child: Opacity(
              opacity: progress,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: collapsedLeading,
                ),
              ),
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }

  Widget _build(
    BuildContext context, {
    required bool scrolled,
    double progress = 1,
  }) {
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
      titleSpacing: _hasSearch && isSearching
          ? 16
          : NavigationToolbar.kMiddleSpacing,
      automaticallyImplyLeading: showBackButton && !isSearching,
      title: _collapsing(
        progress,
        _hasSearch
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
                            context.translate(LanguageLabelKeys.searchHint),
                        onChanged: onSearchChanged ?? (_) {},
                        onCancel: onSearchCancel,
                        cancelIcon: searchCancelIcon,
                      )
                    : AppText(
                        title ?? '',
                        key: const ValueKey('title'),
                        style: context.tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: 0.2,
                        ),
                      ),
              )
            : titleWidget ??
                  (title != null
                      ? (subtitle != null
                            ? Column(
                                mainAxisSize: .min,
                                crossAxisAlignment: .start,
                                children: [
                                  AppText(
                                    title!,
                                    overflow: .ellipsis,
                                    style: context.tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                  AppText(
                                    subtitle!,
                                    overflow: .ellipsis,
                                    style: context.tt.bodySmall?.copyWith(
                                      color: context.cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                            : AppText(
                                title!,
                                style: context.tt.titleMedium?.copyWith(
                                  color: titleColor,
                                ),
                              ))
                      : null),
      ),
      leading: showBackButton && !isSearching
          ? IconButton(
              icon: Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: AppSvgIcon(
                  AssetsConstants.arrowLeftIcon,
                  size: ThemeConstants.iconL,
                  color: titleColor,
                ),
              ),
              onPressed: onBackPressed ?? () => AppNavigator.pop(context),
            )
          : null,
      actions: [
        if (_hasSearch && !isSearching)
          IconButton(
            key: const ValueKey('searchBtn'),
            icon: AppSvgIcon(
              AssetsConstants.searchIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurfaceVariant,
            ),
            onPressed: onSearchStart,
            color: context.cs.onSurfaceVariant,
          ),
        ...?actions,
        if (currentStep != null && totalSteps != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              end: ThemeConstants.paddingL,
            ),
            child: _StepProgressRing(
              currentStep: currentStep!,
              totalSteps: totalSteps!,
            ),
          ),
      ],
      bottom: bottom,
    );
  }
}

class _StepProgressRing extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepProgressRing({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;
    return ExcludeSemantics(
      child: SizedBox(
        width: context.screenWidth * 0.091,
        height: context.screenWidth * 0.091,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              builder: (_, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: context.cs.outlineVariant.withValues(
                  alpha: 0.3,
                ),
                valueColor: AlwaysStoppedAnimation(context.cs.primary),
              ),
            ),
            AppText(
              '${currentStep + 1}/$totalSteps',
              style: context.tt.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: context.cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCancel;
  final String? cancelIcon;

  const _AppBarSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onCancel,
    this.cancelIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final borders = AppDecorations.inputBorderSet(context.cs);
        return Container(
          height: context.screenHeight * 0.049,
          decoration: AppDecorations.card(
            color: context.cs.surface,
            borderRadius: AppRadius.r10,
            border: Border.fromBorderSide(borders.enabledBorder.borderSide),
          ),
          child: Row(
            children: [
              InkWell(
                key: const ValueKey('searchCancel'),
                onTap: onCancel,
                borderRadius: AppRadius.r10,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingS,
                  ),
                  child: cancelIcon != null
                      ? AppSvgIcon(
                          cancelIcon!,
                          size: ThemeConstants.iconS,
                          color: context.cs.onSurfaceVariant,
                        )
                      : Transform.flip(
                          flipX:
                              Directionality.of(context) == TextDirection.rtl,
                          child: AppSvgIcon(
                            AssetsConstants.arrowLeftIcon,
                            size: ThemeConstants.iconS,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              AppSpacing.w4,
              Expanded(
                child: AppTextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  hintText: hint,
                  variant: AppTextFieldVariant.plain,
                  contentPadding: EdgeInsetsDirectional.zero,
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
