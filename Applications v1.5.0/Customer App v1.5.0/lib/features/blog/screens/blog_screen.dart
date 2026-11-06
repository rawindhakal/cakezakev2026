import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/widgets/blog_card.dart';
import 'package:customer/features/blog/widgets/blog_list_skeleton_loader.dart';
import 'package:customer/features/blog/widgets/category_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

typedef _BlogState = PaginationState<Blog>;
typedef _BlogLoaded = PaginationLoaded<Blog>;
typedef _BlogError = PaginationError<Blog>;
typedef _BlogLoading = PaginationLoading<Blog>;
typedef _BlogInitial = PaginationInitial<Blog>;

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<BlogCubit>().fetchMore(),
  );

  @override
  void initState() {
    super.initState();
    context.read<BlogCategoryCubit>().loadCategories();
    context.read<BlogCubit>().loadBlogs();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<BlogCategoryCubit>().loadCategories();
          context.read<BlogCubit>().loadBlogs();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.blog),
            scrollController: _pager.controller,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                context.select<BlogCategoryCubit, bool>((cubit) {
                      final s = cubit.state;
                      return s is BlogCategoryLoaded && s.categories.isNotEmpty;
                    })
                    ? 52
                    : 0,
              ),
              child: const CategoryFilterBar(),
            ),
          ),
          // Offline replaces the body only, so the app bar's back button
          // keeps working.
          body: isOffline
              ? const AppNoInternetView()
              : BlocBuilder<BlogCubit, _BlogState>(
                  builder: (context, state) {
                    if (state is _BlogInitial) {
                      context.read<BlogCubit>().loadBlogs();
                      return const BlogListSkeletonLoader();
                    }
                    if (state is _BlogLoading) {
                      return const BlogListSkeletonLoader();
                    }
                    if (state is _BlogError) {
                      return EmptyStateWidget(
                        imagePath: AssetsConstants.noBlogFound,
                        title: state.message,
                        subtitle: context.translate(
                          LanguageLabelKeys.pullToRefresh,
                        ),
                        onRetry: () => context.read<BlogCubit>().loadBlogs(),
                      );
                    }
                    if (state is _BlogLoaded) {
                      return _buildBlogList(context, state);
                    }
                    return AppSpacing.shrink;
                  },
                ),
        );
      },
    );
  }

  Widget _buildBlogList(BuildContext context, _BlogLoaded state) {
    if (state.data.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noBlogFound,
        title: context.translate(LanguageLabelKeys.noBlogsFound),
        subtitle: context.translate(LanguageLabelKeys.noBlogsCategory),
      );
    }

    return _pager.attach(
      ListView.separated(
        controller: _pager.controller,
        padding: EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL + context.bottomSafePadding,
        ),
        itemCount: state.data.length + (state.isFetchingMore ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.h12,
        itemBuilder: (context, index) {
          if (index == state.data.length) {
            return PaginatedListFooter(
              isLoadingMore: state.isFetchingMore,
              hasMore: state.hasMore,
              skeletonBuilder: (_) =>
                  const BlogListSkeletonLoader(itemCount: 1, shrinkWrap: true),
            );
          }
          return BlogCard(blog: state.data[index]);
        },
      ),
    );
  }
}
