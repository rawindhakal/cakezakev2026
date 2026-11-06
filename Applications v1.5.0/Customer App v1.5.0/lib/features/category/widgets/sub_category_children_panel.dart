import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/commons/widgets/category_tile.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

// Right-side grid shown only for the initial auto-selected category when it
// has children — mirrors CategoryScreen's grid so the UI stays consistent.
class SubCategoryChildrenPanel extends StatelessWidget {
  final PaginationState<Category> state;
  final ValueChanged<Category> onSelect;
  final PaginationScrollController? pager;

  const SubCategoryChildrenPanel({
    super.key,
    required this.state,
    required this.onSelect,
    this.pager,
  });

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  int _crossAxisCount(BuildContext context) => _isTablet(context) ? 5 : 3;

  EdgeInsetsDirectional _gridPadding(BuildContext context) =>
      EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL +
            context.bottomSafePadding +
            // Room for the FloatingCartBar overlaid at the bottom.
            (context.select((CartCubit c) => c.state.totalItems > 0)
                ? FloatingCartBar.barHeight
                : 0),
      );

  SliverGridDelegate _gridDelegate(BuildContext context) {
    final isTablet = _isTablet(context);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _crossAxisCount(context),
      mainAxisSpacing: 6 * (isTablet ? 1.75 : 1.0),
      crossAxisSpacing: 10 * (isTablet ? 1.75 : 1.0),
      childAspectRatio: isTablet ? 0.55 : 0.65,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (state is PaginationLoading<Category> ||
        state is PaginationInitial<Category>) {
      final count = _crossAxisCount(context);
      return GridView.builder(
        padding: _gridPadding(context),
        gridDelegate: _gridDelegate(context),
        itemCount: count * 3,
        itemBuilder: (context, index) => const CategoryTileShimmer(),
      );
    }
    if (state is PaginationError<Category>) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noSearchFound,
        title: (state as PaginationError<Category>).message,
        subtitle: context.translate(LanguageLabelKeys.tapRetry),
      );
    }
    if (state is PaginationLoaded<Category>) {
      final loaded = state as PaginationLoaded<Category>;
      final data = loaded.data;
      if (data.isEmpty) {
        return EmptyStateWidget(
          imagePath: AssetsConstants.noSearchFound,
          title: context.translate(LanguageLabelKeys.noCategoriesFound),
          subtitle: context.translate(LanguageLabelKeys.categoriesEmpty),
        );
      }
      // Load-more tail is shimmer tiles inside the same grid (like
      // CategoryScreen) so the next page fills in place instead of the grid
      // jumping around a spinner row.
      final itemCount =
          data.length + (loaded.isFetchingMore ? _crossAxisCount(context) : 0);

      final grid = GridView.builder(
        controller: pager?.controller,
        padding: _gridPadding(context),
        gridDelegate: _gridDelegate(context),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= data.length) return const CategoryTileShimmer();
          return CategoryTile(
            imageUrl: data[index].imageUrl ?? '',
            name: data[index].name ?? '',
            onTap: () => onSelect(data[index]),
          );
        },
      );
      return pager == null ? grid : pager!.attach(grid);
    }
    return const SizedBox.shrink();
  }
}
