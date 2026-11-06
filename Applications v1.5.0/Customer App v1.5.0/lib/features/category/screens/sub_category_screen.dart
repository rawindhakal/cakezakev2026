import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/widgets/category_swipe_transition.dart';
import 'package:customer/features/category/widgets/sub_category_content_panel.dart';
import 'package:customer/features/category/widgets/sub_category_sidebar_panel.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

class SubCategoryScreen extends StatefulWidget {
  final Category parentCategory;
  final bool showSidebar;

  const SubCategoryScreen({
    super.key,
    required this.parentCategory,
    this.showSidebar = true,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  // Right panel's controller is shared by the product grid and the
  // subcategory-children grid (they occupy the same slot, never both at
  // once) — route load-more to whichever one is actually showing.
  late final _productPager = PaginationScrollController(
    onLoadMore: () {
      if (!widget.showSidebar) {
        context.read<ProductCubit>().loadMore();
        return;
      }
      final state = context.read<SubCategorySelectionCubit>().state;
      if (state is SubCategorySelectionActive &&
          state.rightShowsSubcategories) {
        context.read<SubCategoryChildrenCubit>().loadMore();
      } else {
        context.read<ProductCubit>().loadMore();
      }
    },
  );

  late final _sidebarPager = PaginationScrollController(
    onLoadMore: () {
      final s = context.read<SubCategoryCubit>().state;
      if (s is PaginationLoaded<Category>) {
        context.read<SubCategoryCubit>().loadMore();
      }
    },
  );

  final _swipeTransition = CategorySwipeTransitionController();

  @override
  void initState() {
    super.initState();
    if (widget.showSidebar) {
      context.read<SubCategoryCubit>().loadSubCategories();
    }
  }

  @override
  void dispose() {
    _sidebarPager.dispose();
    _productPager.dispose();
    _swipeTransition.dispose();
    super.dispose();
  }

  // Left panel tap AND the sidebar's own first-item auto-select both call
  // this — identical rule for both, no special-casing the auto pick.
  void _onSelectLeftCategory(Category cat) {
    context.read<SubCategorySelectionCubit>().selectLeft(cat);
  }

  // Sidebar item [offset] places away from the selected one (+1 next, -1
  // previous), or null at either end / before the sidebar has loaded.
  static Category? _neighbour(
    PaginationState<Category> sidebar,
    String? selectedId,
    int offset,
  ) {
    if (sidebar is! PaginationLoaded<Category> || selectedId == null) {
      return null;
    }
    final i = sidebar.data.indexWhere((c) => c.id == selectedId);
    if (i == -1) return null;
    final j = i + offset;
    if (j < 0 || j >= sidebar.data.length) return null;
    return sidebar.data[j];
  }

  void _onSwipeToCategory(Category? cat, SubCategorySwipe swipe) {
    if (cat == null) return;
    // Freeze the current page (as it sits mid-pull) for the slide-out, then
    // switch. Done post-frame: the boundary can't be captured mid-paint.
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted) return;
      _swipeTransition.capture();
      context.read<SubCategorySelectionCubit>().selectLeft(cat, swipe: swipe);
    });
    binding.scheduleFrame();
  }

  // Right panel tap: has_child == true opens a new Category Page (with its
  // own sidebar); has_child == false opens a new Product screen (no
  // sidebar) — same push pattern as CategoryScreen's leaf tap.
  void _onSelectRightItem(Category cat) {
    if (cat.hasChild == true) {
      _openCategoryPage(cat);
    } else {
      _openProductScreen(cat);
    }
  }

  void _openCategoryPage(Category cat) {
    AppNavigator.push(
      context,
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => SubCategoryCubit(parentCategoryId: cat.id ?? ''),
          ),
          BlocProvider(create: (_) => SubCategorySelectionCubit()),
          BlocProvider(create: (_) => SubCategoryChildrenCubit()),
          BlocProvider(create: (_) => ProductCubit()),
          BlocProvider(create: (_) => FilterCubit()),
        ],
        child: SubCategoryScreen(parentCategory: cat),
      ),
    );
  }

  void _openProductScreen(Category cat) {
    AppNavigator.push(
      context,
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                ProductCubit()..loadProducts(categoryId: cat.id ?? ''),
          ),
          BlocProvider(
            create: (_) => FilterCubit()..loadFilters(categoryId: cat.id ?? ''),
          ),
        ],
        child: SubCategoryScreen(parentCategory: cat, showSidebar: false),
      ),
    );
  }

  // Grid-banner "category" redirects land here with only an id (no name
  // fetched yet) — fall back to a generic label instead of a blank app bar.
  String get _title => widget.parentCategory.name?.isNotEmpty == true
      ? widget.parentCategory.name!
      : context.translate(LanguageLabelKeys.categories);

  static bool _rightShowsSubcategories(SubCategorySelectionState state) =>
      state is SubCategorySelectionActive && state.rightShowsSubcategories;

  @override
  Widget build(BuildContext context) {
    if (!widget.showSidebar) {
      return AppScaffold(
        applyBottomInset: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Product-only view always has the filter/sort bar docked under the
        // app bar — keep the app bar flat; no scroll shadow.
        appBar: CustomAppBar(title: _title, showBackButton: true),
        body: Stack(
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                SubCategoryContentPanel(
                  pager: _productPager,
                  selectedCategoryId: widget.parentCategory.id,
                  showSidebar: false,
                  onRetry: () => context.read<ProductCubit>().loadProducts(
                    categoryId: widget.parentCategory.id ?? '',
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: context.bottomSafePadding,
              left: 0,
              right: 0,
              child: FloatingCartBar(
                onViewCart: () =>
                    AppNavigator.pushNamed(context, RouteNames.checkout),
              ),
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Scroll shadow only while the right panel shows subcategories — the
      // product view has the filter/sort bar docked under the app bar instead.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child:
            BlocBuilder<SubCategorySelectionCubit, SubCategorySelectionState>(
              buildWhen: (prev, curr) =>
                  _rightShowsSubcategories(prev) !=
                  _rightShowsSubcategories(curr),
              builder: (context, state) => CustomAppBar(
                title: _title,
                showBackButton: true,
                scrollController: _rightShowsSubcategories(state)
                    ? _productPager.controller
                    : null,
              ),
            ),
      ),
      body: Stack(
        children: [
          BlocListener<SubCategorySelectionCubit, SubCategorySelectionState>(
            listener: (context, state) {
              if (state is! SubCategorySelectionActive) return;
              if (state.rightShowsSubcategories) {
                context.read<SubCategoryChildrenCubit>().switchParent(
                  state.rightCategory.id ?? '',
                );
              } else {
                final id = state.rightCategory.id ?? '';
                context.read<ProductCubit>().loadProducts(categoryId: id);
                context.read<FilterCubit>().loadFilters(categoryId: id);
              }
            },
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Container(
                  decoration: AppDecorations.shadowedCard(
                    color: Theme.of(context).colorScheme.surface,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.zero,
                    blurRadius: 8,
                    offset: const Offset(3, 0),
                  ),
                  child:
                      BlocBuilder<
                        SubCategorySelectionCubit,
                        SubCategorySelectionState
                      >(
                        builder: (context, state) {
                          final active = state is SubCategorySelectionActive
                              ? state
                              : null;
                          return SubCategorySidebarPanel(
                            pager: _sidebarPager,
                            selectedCategoryId: active?.leftSelectedId,
                            autoChildCategoryId:
                                active?.rightShowsSubcategories == true
                                ? active?.rightCategory.id
                                : null,
                            onSelectCategory: _onSelectLeftCategory,
                            onAutoSelectCategory: _onSelectLeftCategory,
                          );
                        },
                      ),
                ),
                BlocBuilder<
                  SubCategorySelectionCubit,
                  SubCategorySelectionState
                >(
                  builder: (context, state) {
                    final active = state is SubCategorySelectionActive
                        ? state
                        : null;
                    // Watched so a sidebar load-more that appends the next
                    // category also refreshes the "next" teaser.
                    final sidebar = context.watch<SubCategoryCubit>().state;
                    final selectedId = active?.leftSelectedId;
                    final next = _neighbour(sidebar, selectedId, 1);
                    final previous = _neighbour(sidebar, selectedId, -1);
                    return SubCategoryContentPanel(
                      pager: _productPager,
                      selectedCategoryId: active?.rightCategory.id,
                      showSidebar: true,
                      swipe: active?.swipe ?? SubCategorySwipe.none,
                      swipeTransition: _swipeTransition,
                      nextCategory: next,
                      previousCategory: previous,
                      onNextCategory: () =>
                          _onSwipeToCategory(next, SubCategorySwipe.next),
                      onPreviousCategory: () => _onSwipeToCategory(
                        previous,
                        SubCategorySwipe.previous,
                      ),
                      autoChildCategory: active?.rightShowsSubcategories == true
                          ? active?.rightCategory
                          : null,
                      onSelectChildCategory: _onSelectRightItem,
                      onRetry: () {
                        final id = active?.rightCategory.id;
                        if (id != null) {
                          context.read<ProductCubit>().loadProducts(
                            categoryId: id,
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // Hairline between the app bar and body — the sidebar shares the
          // app bar's surface color, so without it the two run together.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          Positioned(
            bottom: context.bottomSafePadding,
            left: 0,
            right: 0,
            child: FloatingCartBar(
              onViewCart: () =>
                  AppNavigator.pushNamed(context, RouteNames.checkout),
            ),
          ),
        ],
      ),
    );
  }
}
