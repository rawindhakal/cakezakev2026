import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/cubit/location_cubit.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/features/category/cubit/category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/screens/sub_category_screen.dart';
import 'package:customer/commons/widgets/category_tile.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<CategoryCubit>().loadMore(),
  );

  @override
  void initState() {
    super.initState();
    context.read<CategoryCubit>().loadCategories();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _onCategoryTap(BuildContext context, Category category) {
    if (category.hasChild == true) {
      AppNavigator.push(
        context,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  SubCategoryCubit(parentCategoryId: category.id ?? ''),
            ),
            BlocProvider(create: (_) => SubCategorySelectionCubit()),
            BlocProvider(create: (_) => SubCategoryChildrenCubit()),
            BlocProvider(create: (_) => ProductCubit()),
            BlocProvider(create: (_) => FilterCubit()),
          ],
          child: SubCategoryScreen(parentCategory: category),
        ),
      );
    } else {
      AppNavigator.push(
        context,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  ProductCubit()..loadProducts(categoryId: category.id ?? ''),
            ),
            BlocProvider(
              create: (_) =>
                  FilterCubit()..loadFilters(categoryId: category.id ?? ''),
            ),
          ],
          child: SubCategoryScreen(
            parentCategory: category,
            showSidebar: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, int>(
      listener: (context, state) =>
          context.read<CategoryCubit>().loadCategories(),
      child: BlocConsumer<ConnectivityCubit, ConnectivityState>(
        listener: (context, state) {
          if (state is ConnectivityConnected) {
            context.read<CategoryCubit>().loadCategories();
          }
        },
        builder: (context, connectivityState) {
          return AppScaffold(
            applyBottomInset: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: CustomAppBar(
              title: context.translate(LanguageLabelKeys.categories),
              showBackButton: false,
              scrollController: _pager.controller,
            ),
            // Offline lives in the body so the app bar (and its back button on
            // the pushed-route variant of this screen) stays usable.
            body: connectivityState is ConnectivityDisconnected
                ? const AppNoInternetView()
                : BlocBuilder<CategoryCubit, PaginationState<Category>>(
                    builder: (context, state) {
                      if (state is PaginationInitial<Category>) {
                        context.read<CategoryCubit>().loadCategories();
                        return _buildSkeletonGrid(context);
                      }
                      if (state is PaginationLoading<Category>) {
                        return _buildSkeletonGrid(context);
                      }
                      if (state is PaginationError<Category>) {
                        return EmptyStateWidget(
                          imagePath: AssetsConstants.noSearchFound,
                          title: state.message,
                          subtitle: context.translate(
                            LanguageLabelKeys.pullToRefresh,
                          ),
                          onRetry: () => context
                              .read<CategoryCubit>()
                              .loadCategories(emitLoadingState: true),
                        );
                      }
                      if (state is PaginationLoaded<Category>) {
                        return _buildGrid(state);
                      }
                      return AppSpacing.shrink;
                    },
                  ),
          );
        },
      ),
    );
  }

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  Widget _buildSkeletonGrid(BuildContext context) {
    final isTablet = _isTablet(context);
    final crossAxisCount = isTablet ? 6 : 4;
    return GridView.builder(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL + context.bottomSafePadding,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6 * (isTablet ? 1.75 : 1.0),
        crossAxisSpacing: 10 * (isTablet ? 1.75 : 1.0),
        childAspectRatio: isTablet ? 0.55 : 0.65,
      ),
      itemCount: crossAxisCount * 3,
      itemBuilder: (context, index) => const CategoryTileShimmer(),
    );
  }

  Widget _buildGrid(PaginationLoaded<Category> state) {
    if (state.data.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noSearchFound,
        title: context.translate(LanguageLabelKeys.noCategoriesFound),
        subtitle: context.translate(LanguageLabelKeys.categoriesEmpty),
      );
    }

    final itemCount = state.data.length + (state.isFetchingMore ? 4 : 0);
    final isTablet = _isTablet(context);
    final crossAxisCount = isTablet ? 6 : 4;

    return RefreshIndicator(
      color: context.cs.primary,
      // Grid stays on screen; the spinner ends when the new list lands.
      onRefresh: () => context.read<CategoryCubit>().loadCategories(),
      child: _pager.attach(
        GridView.builder(
          controller: _pager.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingM,
            ThemeConstants.paddingL,
            ThemeConstants.paddingM,
            ThemeConstants.paddingL + context.bottomSafePadding,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6 * (isTablet ? 1.75 : 1.0),
            crossAxisSpacing: 10 * (isTablet ? 1.75 : 1.0),
            childAspectRatio: isTablet ? 0.55 : 0.65,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= state.data.length) {
              return const CategoryTileShimmer();
            }
            return CategoryTile(
              imageUrl: state.data[index].imageUrl ?? '',
              name: state.data[index].name ?? '',
              onTap: () => _onCategoryTap(context, state.data[index]),
            );
          },
        ),
      ),
    );
  }
}
