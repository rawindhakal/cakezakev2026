import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/widgets/sub_category_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class SubCategorySidebarPanel extends StatefulWidget {
  final PaginationScrollController pager;
  final String? selectedCategoryId;
  // Id of the category currently previewed as a right-side grid (only ever
  // the very first auto-selected category). That one item legitimately
  // shows its own content on the right, so it's the one has_child exception
  // allowed to render as selected.
  final String? autoChildCategoryId;
  final ValueChanged<Category> onSelectCategory;
  final ValueChanged<Category> onAutoSelectCategory;

  const SubCategorySidebarPanel({
    super.key,
    required this.pager,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onAutoSelectCategory,
    this.autoChildCategoryId,
  });

  @override
  State<SubCategorySidebarPanel> createState() =>
      _SubCategorySidebarPanelState();
}

class _SubCategorySidebarPanelState extends State<SubCategorySidebarPanel>
    with SingleTickerProviderStateMixin {
  // Blinkit: the bar glides to the tapped item first, and only once it lands
  // does that item switch to its selected look (the old one lets go at once).
  static const _slideDuration = Duration(milliseconds: 300);
  static const _indicatorInset = 1.5;

  final _stackKey = GlobalKey();
  final _itemKeys = <String, GlobalKey>{};

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: _slideDuration,
  );
  late final Animation<double> _slideCurve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeInOut,
  );

  /// Item the bar is heading to (drives scroll-reveal).
  String? _targetId;

  /// Item currently drawn in its selected style.
  String? _activeId;

  // Bar rect in scroll-content coordinates (top, height).
  Rect? _from;
  Rect? _to;

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  double get _scrollOffset {
    final c = widget.pager.controller;
    return c.hasClients ? c.offset : 0;
  }

  /// Selected item's rect within the scroll content, or null if it isn't
  /// laid out (scrolled far off-screen).
  Rect? _measure(String id) {
    final item = _itemKeys[id]?.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (item is! RenderBox || stack is! RenderBox || !item.attached) {
      return null;
    }
    final top = item.localToGlobal(Offset.zero, ancestor: stack).dy;
    return Rect.fromLTWH(0, top + _scrollOffset, 0, item.size.height);
  }

  Rect? get _currentRect {
    if (_to == null) return null;
    if (_from == null) return _to;
    return Rect.lerp(_from, _to, _slideCurve.value);
  }

  void _activate(String id) {
    setState(() => _activeId = id);
    // The bold selected label can wrap differently, so re-fit the bar to the
    // item's settled height.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeId != id) return;
      final rect = _measure(id);
      if (rect != null && rect != _to) {
        setState(() {
          _from = null;
          _to = rect;
        });
      }
    });
  }

  void _onTargetChanged(String? id) {
    final previous = _targetId;
    _targetId = id;
    // Called from build, so every state change waits for the next frame
    // (which is also when the target item has been laid out to measure).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _targetId != id) return;
      if (id == null) {
        _slide.stop();
        setState(() {
          _activeId = null;
          _from = _to = null;
        });
        return;
      }
      final rect = _measure(id);
      final start = _currentRect;
      if (rect == null || start == null || previous == null) {
        // First selection (or nothing to glide from): just appear.
        _slide.value = 1;
        _from = null;
        _to = rect;
        _activate(id);
        return;
      }
      setState(() {
        _activeId = null;
        _from = start;
        _to = rect;
      });
      _slide.forward(from: 0).whenComplete(() {
        if (!mounted || _targetId != id) return;
        _activate(id);
      });
    });
  }

  String? _effectiveSelectedId(List<Category> data) {
    final id = widget.selectedCategoryId;
    if (id == null) return null;
    for (final cat in data) {
      if (cat.id != id) continue;
      // A has_child item only reads as "selected" if it's the one previewed
      // as a grid on the right; otherwise tapping it drills into its own
      // page instead of showing content here, so it shouldn't look selected.
      return cat.hasChild != true || cat.id == widget.autoChildCategoryId
          ? id
          : null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Matches CustomAppBar's default background so the sidebar reads as one
    // continuous surface with the app bar above it.
    final sidebarBg = context.cs.surface;

    return SizedBox(
      width: SidebarMetrics.width,
      child: BlocConsumer<SubCategoryCubit, PaginationState<Category>>(
        listener: (context, state) {
          if (state is PaginationLoaded<Category>) {
            // Fetch every icon up front so the first tap on any category
            // never has to wait on a cold network fetch — only ever hits
            // this once per screen since the cubit only loads once.
            for (final cat in state.data) {
              final url = cat.imageUrl ?? '';
              if (url.isEmpty) continue;
              // Same size as SidebarItem's AppNetworkImage so this lands in
              // the image cache under the key build() looks up.
              AppNetworkImage.precache(
                context,
                url,
                width: SidebarMetrics.image,
                height: SidebarMetrics.image,
              );
            }
          }
          if (state is PaginationLoaded<Category> &&
              state.data.isNotEmpty &&
              widget.selectedCategoryId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onAutoSelectCategory(state.data.first);
            });
          }
        },
        builder: (context, state) {
          if (state is PaginationLoading<Category>) {
            return SidebarLoader(bg: sidebarBg);
          }
          if (state is PaginationError<Category>) {
            return Container(
              padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
              color: sidebarBg,
              alignment: AlignmentDirectional.center,
              child: AppText(
                state.message,
                style: context.tt.labelSmall?.copyWith(fontSize: 10),
                textAlign: .center,
              ),
            );
          }
          if (state is PaginationLoaded<Category>) {
            final selectedId = _effectiveSelectedId(state.data);
            if (selectedId != _targetId) _onTargetChanged(selectedId);

            return Container(
              color: sidebarBg,
              child: Stack(
                key: _stackKey,
                children: [
                  widget.pager.attach(
                    ListView.builder(
                      controller: widget.pager.controller,
                      itemCount: state.data.length,
                      itemBuilder: (context, index) {
                        final cat = state.data[index];
                        final id = cat.id;
                        return _RevealWhenSelected(
                          key: id == null ? null : _keyFor(id),
                          isSelected: id != null && id == selectedId,
                          child: SidebarItem(
                            category: cat,
                            isSelected: id != null && id == _activeId,
                            onTap: () => widget.onSelectCategory(cat),
                          ),
                        );
                      },
                    ),
                  ),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _slide,
                      widget.pager.controller,
                    ]),
                    builder: (context, _) {
                      final rect = _currentRect;
                      if (rect == null) return AppSpacing.shrink;
                      return PositionedDirectional(
                        end: 0,
                        top: rect.top - _scrollOffset + _indicatorInset,
                        height: rect.height - _indicatorInset * 2,
                        width: SidebarMetrics.indicatorWidth,
                        child: const IgnorePointer(child: SidebarIndicator()),
                      );
                    },
                  ),
                ],
              ),
            );
          }
          return AppSpacing.shrink;
        },
      ),
    );
  }
}

/// Scrolls its item to the middle of the sidebar the moment it becomes
/// selected — keeps the highlighted category in view when the selection
/// moves via a next/previous swipe on the product list.
class _RevealWhenSelected extends StatefulWidget {
  final bool isSelected;
  final Widget child;

  const _RevealWhenSelected({
    super.key,
    required this.isSelected,
    required this.child,
  });

  @override
  State<_RevealWhenSelected> createState() => _RevealWhenSelectedState();
}

class _RevealWhenSelectedState extends State<_RevealWhenSelected> {
  @override
  void didUpdateWidget(covariant _RevealWhenSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
