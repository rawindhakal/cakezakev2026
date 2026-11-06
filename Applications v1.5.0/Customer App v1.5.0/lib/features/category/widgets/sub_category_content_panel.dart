import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/widgets/category_swipe_transition.dart';
import 'package:customer/features/category/widgets/sub_category_children_panel.dart';
import 'package:customer/features/category/widgets/sub_category_filter_bar.dart';
import 'package:customer/features/category/widgets/sub_category_product_panel.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_text.dart';

typedef _ProductState = PaginationState<ProductDataModel>;

class SubCategoryContentPanel extends StatelessWidget {
  final PaginationScrollController pager;
  final String? selectedCategoryId;
  final VoidCallback onRetry;
  final bool showSidebar;
  // Non-null only for the initial auto-selected category when it has children —
  // shows its direct subcategories here instead of the product grid.
  final Category? autoChildCategory;
  final ValueChanged<Category>? onSelectChildCategory;
  // Sidebar neighbours reachable by pulling past either end of the list.
  final Category? nextCategory;
  final Category? previousCategory;
  final VoidCallback? onNextCategory;
  final VoidCallback? onPreviousCategory;
  // Side the current category's content slides in from.
  final SubCategorySwipe swipe;
  // Captures the outgoing page for the swipe transition (sidebar mode only).
  final CategorySwipeTransitionController? swipeTransition;

  const SubCategoryContentPanel({
    super.key,
    required this.pager,
    required this.selectedCategoryId,
    required this.onRetry,
    this.showSidebar = true,
    this.autoChildCategory,
    this.onSelectChildCategory,
    this.nextCategory,
    this.previousCategory,
    this.onNextCategory,
    this.onPreviousCategory,
    this.swipe = SubCategorySwipe.none,
    this.swipeTransition,
  });

  Widget _productSkeleton(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return ProductGridSkeleton(
      crossAxisCount: showSidebar ? (isTablet ? 3 : 2) : (isTablet ? 5 : 3),
      spacing: ThemeConstants.spaceS * (isTablet ? 1.75 : 1.0),
      mainAxisSpacing: 12 * (isTablet ? 1.75 : 1.0),
    );
  }

  // On open nothing is selected yet only because the sidebar is still
  // loading its first item (which auto-selects itself) — keep the skeleton
  // up through that gap instead of flashing the "select a category" prompt.
  // The prompt is still the right answer once the sidebar has settled with
  // nothing to auto-select: an error, or an empty list.
  Widget _initialPlaceholder(BuildContext context) {
    if (!showSidebar) return _productSkeleton(context);
    return BlocBuilder<SubCategoryCubit, PaginationState<Category>>(
      builder: (context, sidebarState) {
        final nothingToSelect =
            sidebarState is PaginationError<Category> ||
            (sidebarState is PaginationLoaded<Category> &&
                sidebarState.data.isEmpty);
        if (!nothingToSelect) return _productSkeleton(context);
        return Center(
          child: AppText(
            context.translate(LanguageLabelKeys.selectACategory),
            style: context.tt.bodySmall?.copyWith(
              fontSize: 13,
              color: context.cs.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget page;
    if (autoChildCategory != null) {
      page = BlocBuilder<SubCategoryChildrenCubit, PaginationState<Category>>(
        builder: (context, state) => SubCategoryChildrenPanel(
          state: state,
          pager: pager,
          onSelect: onSelectChildCategory ?? (_) {},
        ),
      );
    } else {
      page = BlocBuilder<ProductCubit, _ProductState>(
        builder: (context, state) {
          // Hold the skeleton while a category swipe is still sliding:
          // swapping the grid in mid-motion (new layout + image decodes) is
          // what made the slide jump/stutter. It fades in once it lands.
          final sliding = CategorySwipeTransition.slidingOf(context);
          final Widget body;
          if (state is PaginationInitial<ProductDataModel>) {
            body = KeyedSubtree(
              key: const ValueKey('initial'),
              child: _initialPlaceholder(context),
            );
          } else if (state is PaginationLoading<ProductDataModel> ||
              (sliding && state is PaginationLoaded<ProductDataModel>)) {
            // Filter chips are part of the page now (pinned in the list), so
            // the loading page carries their placeholder too.
            body = Column(
              key: const ValueKey('loading'),
              children: [
                const SubCategoryFilterBarSkeleton(),
                Expanded(child: _productSkeleton(context)),
              ],
            );
          } else if (state is PaginationError<ProductDataModel>) {
            body = EmptyStateWidget(
              key: const ValueKey('error'),
              imagePath: AssetsConstants.noSearchFound,
              title: state.message,
              subtitle: context.translate(LanguageLabelKeys.tapRetry),
              onRetry: onRetry,
            );
          } else if (state is PaginationLoaded<ProductDataModel>) {
            body = KeyedSubtree(
              key: const ValueKey('loaded'),
              child: pager.attach(
                SubCategoryProductPanel(
                  state: state,
                  controller: pager.controller,
                  showSidebar: showSidebar,
                  // Part of the page (not a separate panel row) so it slides
                  // with the page on a category swipe; the previous-category
                  // header opens just below it.
                  header: SubCategoryFilterBar(state: state),
                  nextCategory: nextCategory,
                  previousCategory: previousCategory,
                  onNextCategory: onNextCategory,
                  onPreviousCategory: onPreviousCategory,
                ),
              ),
            );
          } else {
            body = AppSpacing.shrink;
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: body,
          );
        },
      );
    }
    return Expanded(
      child: CategorySwipeTransition(
        controller: swipeTransition,
        pageKey: selectedCategoryId,
        swipe: swipe,
        child: page,
      ),
    );
  }
}
