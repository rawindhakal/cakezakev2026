import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/features/faq/cubit/faq_cubit.dart';
import 'package:customer/features/faq/widgets/faq_list_skeleton_loader.dart';
import 'package:customer/features/faq/widgets/faq_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/features/faq/models/faq_model.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

typedef FaqPaginationState = PaginationState<FaqData>;
typedef FaqLoaded = PaginationLoaded<FaqData>;
typedef FaqError = PaginationError<FaqData>;
typedef FaqLoading = PaginationLoading<FaqData>;

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<FaqCubit>().fetchMore(),
  );

  @override
  void initState() {
    super.initState();
    context.read<FaqCubit>().fetchInitial();
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
          context.read<FaqCubit>().fetchInitial();
        }
      },
      builder: (context, connectivityState) {
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.faq),
            scrollController: _pager.controller,
          ),
          // Offline replaces the body only, so the app bar's back button
          // keeps working.
          body: connectivityState is ConnectivityDisconnected
              ? const AppNoInternetView()
              : RefreshIndicator(
                  onRefresh: () async => context.read<FaqCubit>().refresh(),
                  color: context.cs.primary,
                  child: BlocBuilder<FaqCubit, FaqPaginationState>(
                    builder: (context, state) {
                      if (state is FaqLoading) {
                        return const FaqListSkeletonLoader();
                      }
                      if (state is FaqError) {
                        return EmptyStateWidget(
                          imagePath: AssetsConstants.noSearchFound,
                          title: state.message,
                          subtitle: context.translate(
                            LanguageLabelKeys.pullToRefresh,
                          ),
                          onRetry: () => context.read<FaqCubit>().refresh(),
                        );
                      }
                      if (state is FaqLoaded) {
                        return _buildFaqList(context, state);
                      }
                      return AppSpacing.shrink;
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFaqList(BuildContext context, FaqLoaded state) {
    if (state.data.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noSearchFound,
        title: context.translate(LanguageLabelKeys.noFaqsFound),
        subtitle: context.translate(LanguageLabelKeys.noFaqsAvailable),
      );
    }

    return _pager.attach(
      ListView.builder(
        controller: _pager.controller,
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL + context.bottomSafePadding,
        ),
        itemCount: state.data.length + (state.isFetchingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.data.length) {
            return PaginatedListFooter(
              isLoadingMore: state.isFetchingMore,
              hasMore: state.hasMore,
              skeletonBuilder: (_) =>
                  const FaqListSkeletonLoader(itemCount: 2, shrinkWrap: true),
            );
          }
          return FaqTile(faq: state.data[index]);
        },
      ),
    );
  }
}
