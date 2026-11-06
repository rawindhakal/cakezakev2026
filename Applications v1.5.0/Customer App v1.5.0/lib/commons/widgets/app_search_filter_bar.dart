import 'dart:async';

import 'package:customer/commons/widgets/app_icon_filter_button.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class AppSearchFilterBar extends StatefulWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSubmitted;
  // When null, the sort/filter icon is hidden entirely.
  final VoidCallback? onDateRange;
  final VoidCallback? onClearFilters;
  final bool hasDateFilter;
  final String? dateRangeLabel;
  final bool hasActiveFilters;
  final String? hintText;
  final String filterIcon;
  final VoidCallback? onMicTap;
  final bool isListening;
  // Overrides the default search icon at the field's start (e.g. a back
  // arrow). Tapping it fires [onPrefixTap] instead of just being decorative.
  final String? prefixIconAsset;
  final VoidCallback? onPrefixTap;
  final bool autofocus;
  // Words to rotate through as an animated placeholder (e.g. API-driven
  // search suggestions). Falls back to the static [hintText] when null or
  // empty — no hardcoded default words.
  final List<String>? hintSuggestions;

  const AppSearchFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    this.onSubmitted,
    this.onDateRange,
    this.onClearFilters,
    this.hasDateFilter = false,
    this.dateRangeLabel,
    this.hasActiveFilters = false,
    this.hintText = 'Search by order ID or customer…',
    this.filterIcon = AssetsConstants.dateIcon,
    this.onMicTap,
    this.isListening = false,
    this.prefixIconAsset,
    this.onPrefixTap,
    this.autofocus = false,
    this.hintSuggestions,
  });

  @override
  State<AppSearchFilterBar> createState() => _AppSearchFilterBarState();
}

class _AppSearchFilterBarState extends State<AppSearchFilterBar> {
  int _hintIndex = 0;
  Timer? _timer;
  final FocusNode _focusNode = FocusNode();

  List<String> get _hints => widget.hintSuggestions?.isNotEmpty ?? false
      ? widget.hintSuggestions!
      : const [];

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onControllerChanged);
    // Cursor sits where the hint overlay is drawn — hide the overlay once
    // focused so the blinking caret never overlaps the animated text.
    _focusNode.addListener(_onControllerChanged);
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant AppSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onControllerChanged);
      widget.searchController.addListener(_onControllerChanged);
    }
    if (oldWidget.hintSuggestions != widget.hintSuggestions) {
      _hintIndex = 0;
      _restartTimer();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_hints.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.searchController.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borders = AppDecorations.inputBorderSet(context.cs);
    final hints = _hints;
    final showAnimatedHint =
        hints.isNotEmpty && widget.searchController.text.isEmpty;
    final hintStyle = context.tt.bodyMedium?.copyWith(
      color: context.cs.onSurfaceVariant,
    );
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                TextFormField(
                  controller: widget.searchController,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  onChanged: widget.onSearchChanged,
                  onFieldSubmitted: widget.onSubmitted,
                  style: context.tt.bodyMedium,
                  decoration: InputDecoration(
                    hintText: showAnimatedHint ? '' : widget.hintText,
                    hintStyle: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    prefixIcon: GestureDetector(
                      onTap: widget.onPrefixTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: ThemeConstants.paddingM,
                          end: ThemeConstants.paddingS,
                        ),
                        child: AppSvgIcon(
                          widget.prefixIconAsset ?? AssetsConstants.searchIcon,
                          size: ThemeConstants.iconM,
                          color: context.cs.onSurfaceVariant,
                          fit: widget.prefixIconAsset != null
                              ? BoxFit.contain
                              : BoxFit.scaleDown,
                          bakeTint: true,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    suffixIcon: widget.searchController.text.isNotEmpty
                        ? IconButton(
                            icon: AppSvgIcon(
                              AssetsConstants.closeIcon,
                              size: ThemeConstants.iconS,
                              color: context.cs.onSurfaceVariant,
                              bakeTint: true,
                            ),
                            padding: EdgeInsetsDirectional.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () {
                              widget.searchController.clear();
                              widget.onSubmitted != null
                                  ? widget.onSubmitted!('')
                                  : widget.onSearchChanged('');
                            },
                          )
                        : widget.onMicTap != null
                        ? Row(
                            mainAxisSize: .min,
                            children: [
                              SizedBox(
                                height: 22,
                                child: VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: context.cs.outlineVariant,
                                ),
                              ),
                              IconButton(
                                icon: AppSvgIcon(
                                  AssetsConstants.microphoneIcon,
                                  size: ThemeConstants.iconM,
                                  color: widget.isListening
                                      ? context.cs.primary
                                      : context.cs.onSurfaceVariant,
                                  bakeTint: true,
                                ),
                                padding: EdgeInsetsDirectional.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: widget.onMicTap,
                              ),
                            ],
                          )
                        : null,
                    filled: true,
                    fillColor: context.cs.surface,
                    isDense: true,
                    visualDensity: VisualDensity(vertical: -4, horizontal: -4),
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingM,
                      vertical: ThemeConstants.paddingXS,
                    ),
                    border: borders.border,
                    enabledBorder: borders.enabledBorder,
                    // Neutral on focus — no primary-color pop, matches idle state.
                    focusedBorder: borders.enabledBorder,
                  ),
                ),
                if (showAnimatedHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          // Extra 4dp past the icon gives the blinking caret
                          // room before the hint text starts, so they never
                          // visually overlap while still animating on focus.
                          start:
                              ThemeConstants.paddingM +
                              ThemeConstants.iconM +
                              ThemeConstants.paddingS +
                              4,
                          // Reserve the suffix icon's zone so long hint text
                          // ellipsizes before reaching it instead of running
                          // underneath the mic button.
                          end: widget.onMicTap != null
                              ? ThemeConstants.paddingM +
                                    ThemeConstants.iconM +
                                    ThemeConstants.paddingM
                              : ThemeConstants.paddingM,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          // Static "Search" prefix — only the quoted
                          // suggestion animates.
                          child: Row(
                            children: [
                              AppText(
                                '${context.translate(LanguageLabelKeys.search)} ',
                                style: hintStyle,
                                maxLines: 1,
                              ),
                              Expanded(
                                child: ClipRect(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    transitionBuilder: (child, animation) {
                                      // Incoming slides up from below, outgoing
                                      // slides out upward — same as the home
                                      // search bar.
                                      final isEntering =
                                          (child.key as ValueKey<int>).value ==
                                          _hintIndex;
                                      return FadeTransition(
                                        opacity: CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeInOut,
                                        ),
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: Offset(
                                                  0,
                                                  isEntering ? 0.5 : -0.5,
                                                ),
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
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: AppText(
                                        '"${hints[_hintIndex % hints.length]}"',
                                        style: hintStyle,
                                        maxLines: 1,
                                        overflow: .ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.onDateRange != null) ...[
            AppSpacing.w8,
            AppIconFilterButton(
              icon: widget.filterIcon,
              isActive: widget.hasDateFilter,
              onTap: widget.onDateRange!,
              tooltip:
                  widget.dateRangeLabel ??
                  context.translate(LanguageLabelKeys.filterByDate),
            ),
          ],
          if (widget.hasActiveFilters && widget.onClearFilters != null) ...[
            AppSpacing.w6,
            AppIconFilterButton(
              icon: AssetsConstants.closeIcon,
              isActive: false,
              onTap: widget.onClearFilters!,
              tooltip: context.translate(LanguageLabelKeys.clearFiltersTooltip),
            ),
          ],
        ],
      ),
    );
  }
}
