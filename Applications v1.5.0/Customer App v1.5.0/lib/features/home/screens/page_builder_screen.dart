import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/screens/sub_category_screen.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/home/cubits/page_builder_cubit.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/widgets/back_to_top_button.dart';
import 'package:customer/features/home/widgets/section_widget.dart';
import 'package:customer/features/home/widgets/skeleton_loader.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PageBuilderScreen extends StatefulWidget {
  final String id;

  const PageBuilderScreen({super.key, required this.id});

  @override
  State<PageBuilderScreen> createState() => _PageBuilderScreenState();
}

class _PageBuilderScreenState extends State<PageBuilderScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolled = ValueNotifier(false);
  final ValueNotifier<bool> _showAppBar = ValueNotifier(true);
  double _lastScrollOffset = 0;

  static const double _kScrollThreshold = 80.0;
  static const double _kAppBarHideThreshold = 10.0;

  static const double _kLoadMoreTriggerFraction = 0.7;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<PageBuilderCubit>().loadPageBuilder(id: widget.id);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isScrolled.dispose();
    _showAppBar.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final scrollingUp = offset < _lastScrollOffset;
    _lastScrollOffset = offset;
    final shouldShow = offset > _kScrollThreshold && scrollingUp;
    if (shouldShow != _isScrolled.value) _isScrolled.value = shouldShow;

    final atEnd = maxExtent > 0 && offset >= maxExtent - _kAppBarHideThreshold;
    final shouldShowAppBar = offset <= _kAppBarHideThreshold || atEnd;
    if (shouldShowAppBar != _showAppBar.value) {
      _showAppBar.value = shouldShowAppBar;
    }

    if (maxExtent > 0 && offset >= maxExtent * _kLoadMoreTriggerFraction) {
      context.read<PageBuilderCubit>().loadMoreSections();
    }
  }

  Widget _buildSections(
    BuildContext context,
    List<Sections> sections, {
    bool isLoadingMore = false,
  }) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset)),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              ...sections.map(
                (s) => SectionWidget(
                  section: s,
                  onCategoryTap: (cat) {
                    if (cat.id == null) return;
                    final category = Category(
                      id: cat.id.toString(),
                      name: cat.name,
                      imageUrl: cat.imageUrl,
                      hasChild: cat.hasChild ?? false,
                    );
                    if (category.hasChild == true) {
                      AppNavigator.push(
                        context,
                        MultiBlocProvider(
                          providers: [
                            BlocProvider(
                              create: (_) => SubCategoryCubit(
                                parentCategoryId: category.id!,
                              ),
                            ),
                            BlocProvider(
                              create: (_) => SubCategorySelectionCubit(),
                            ),
                            BlocProvider(
                              create: (_) => SubCategoryChildrenCubit(),
                            ),
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
                              create: (_) => SubCategoryCubit(
                                parentCategoryId: category.id!,
                              ),
                            ),
                            BlocProvider(
                              create: (_) =>
                                  ProductCubit()
                                    ..loadProducts(categoryId: category.id!),
                            ),
                            BlocProvider(
                              create: (_) =>
                                  FilterCubit()
                                    ..loadFilters(categoryId: category.id!),
                            ),
                          ],
                          child: SubCategoryScreen(
                            parentCategory: category,
                            showSidebar: false,
                          ),
                        ),
                      );
                    }
                  },
                  onProductTap: (product) {
                    if (product.id != null) {
                      AppNavigator.pushNamed(
                        context,
                        RouteNames.productDetail,
                        arguments: product.id,
                      );
                    }
                  },
                  onBrandTap: (brand) {
                    if (brand.id == null) return;
                    AppNavigator.push(
                      context,
                      BlocProvider(
                        create: (_) => ProductCubit(),
                        child: ProductScreen(
                          title: brand.name?.isNotEmpty == true
                              ? brand.name!
                              : context.translate(LanguageLabelKeys.brand),
                          brandId: brand.id.toString(),
                        ),
                      ),
                    );
                  },
                  onViewMoreTap: (title, scope) {
                    AppNavigator.push(
                      context,
                      BlocProvider(
                        create: (_) => ProductCubit(),
                        child: ProductScreen(
                          title: title.isNotEmpty
                              ? title
                              : context.translate(LanguageLabelKeys.products),
                          categoryId: scope.categoryIds,
                          dataSource: scope.dataSource,
                          manualProductIds: scope.manualProductIds,
                          scopeBrandIds: scope.brandIds,
                          filterMode: scope.filterMode,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (isLoadingMore) const SkeletonLoader(),
            ],
          ),
        ),
        if (context.select((CartCubit c) => c.state.totalItems > 0))
          const SliverToBoxAdapter(
            child: SizedBox(height: FloatingCartBar.barHeight),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PageBuilderCubit, PageBuilderState>(
      builder: (context, state) {
        final page = state is PageBuilderLoaded
            ? state.pageLayout.data?.page
            : null;
        return AppScaffold(
          extendBodyBehindAppBar: true,
          applyBottomInset: false,
          appBar: _CollapsibleAppBar(
            title: page?.title ?? '',
            headerColor: page?.headerColor.toColor(),
            titleColor: page?.titleColor.toColor(),
            showListenable: _showAppBar,
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PageBuilderState state) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    if (state is PageBuilderLoading || state is PageBuilderInitial) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: const SkeletonLoader(),
        ),
      );
    }
    if (state is PageBuilderError) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: EmptyStateWidget(
            imagePath: AssetsConstants.noSearchFound,
            title: state.message,
            subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
            onRetry: () => context.read<PageBuilderCubit>().loadPageBuilder(
              id: widget.id,
              emitLoadingState: true,
            ),
          ),
        ),
      );
    }
    if (state is PageBuilderLoaded) {
      final sections = state.pageLayout.data?.page?.sections ?? [];
      if (sections.isEmpty) {
        return Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Center(
            child: EmptyStateWidget(
              imagePath: AssetsConstants.noSearchFound,
              title: context.translate(LanguageLabelKeys.noProductsFound),
              subtitle: context.translate(
                LanguageLabelKeys.noProductsFoundSubtitle,
              ),
            ),
          ),
        );
      }
      return Stack(
        children: [
          RefreshIndicator(
            // Sections stay on screen; the spinner ends when the new page
            // lands.
            onRefresh: () =>
                context.read<PageBuilderCubit>().loadPageBuilder(id: widget.id),
            child: _buildSections(
              context,
              sections,
              isLoadingMore: state.isLoadingMore,
            ),
          ),
          Positioned(
            top:
                MediaQuery.of(context).padding.top +
                kToolbarHeight +
                ThemeConstants.paddingS,
            left: 0,
            right: 0,
            child: Center(
              child: BackToTopButton(
                visibleListenable: _isScrolled,
                onTap: () {
                  if (!_scrollController.hasClients) return;
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                },
              ),
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
      );
    }
    return const SizedBox.shrink();
  }
}

// Fades the title out and the app bar background to transparent on
// scroll-down (back button stays put), restoring both on scroll-up
// or at the top.
class _CollapsibleAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  // API-provided colors; null falls back to the theme surface/onSurface.
  final Color? headerColor;
  final Color? titleColor;
  final ValueListenable<bool> showListenable;

  const _CollapsibleAppBar({
    required this.title,
    this.headerColor,
    this.titleColor,
    required this.showListenable,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final fgColor = titleColor ?? context.cs.onSurface;
    return ValueListenableBuilder<bool>(
      valueListenable: showListenable,
      builder: (context, show, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          color: show
              ? (headerColor ?? context.cs.surface)
              : Colors.transparent,
          child: CustomAppBar(
            title: title,
            backgroundColor: Colors.transparent,
            foregroundColor: fgColor,
            titleWidget: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: show ? 1 : 0,
              child: AppText(
                title,
                style: context.tt.titleLarge?.copyWith(color: fgColor),
              ),
            ),
          ),
        );
      },
    );
  }
}
