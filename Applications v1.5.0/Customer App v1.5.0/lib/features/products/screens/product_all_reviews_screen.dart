import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/products/cubit/ratings_list_cubit.dart';
import 'package:customer/features/products/models/product_rating_model.dart';
import 'package:customer/features/products/widgets/product_detail_rating_section.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductAllReviewsArgs {
  final String productId;
  // Reuses the product-detail page's already-loaded cubit instance so the
  // list opens instantly instead of refetching page 1.
  final RatingsListCubit ratingsCubit;

  const ProductAllReviewsArgs({
    required this.productId,
    required this.ratingsCubit,
  });
}

class ProductAllReviewsScreen extends StatefulWidget {
  final ProductAllReviewsArgs args;

  const ProductAllReviewsScreen({super.key, required this.args});

  @override
  State<ProductAllReviewsScreen> createState() =>
      _ProductAllReviewsScreenState();
}

class _ProductAllReviewsScreenState extends State<ProductAllReviewsScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => widget.args.ratingsCubit.loadMore(),
  );

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.args.ratingsCubit,
      child: AppScaffold(
        applyBottomInset: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.ratingsAndReviews),
        ),
        body: BlocBuilder<RatingsListCubit, PaginationState<ProductRatingList>>(
          builder: (context, state) {
            if (state is! PaginationLoaded<ProductRatingList>) {
              return const Center(child: LoadingWidget());
            }

            final summary = widget.args.ratingsCubit.summary;
            final avgRating =
                double.tryParse(summary.averageRating ?? '0') ?? 0.0;
            final total =
                (int.tryParse(summary.oneStarRating ?? '0') ?? 0) +
                (int.tryParse(summary.twoStarRating ?? '0') ?? 0) +
                (int.tryParse(summary.threeStarRating ?? '0') ?? 0) +
                (int.tryParse(summary.fourStarRating ?? '0') ?? 0) +
                (int.tryParse(summary.fiveStarRating ?? '0') ?? 0);

            if (state.data.isEmpty) {
              return EmptyStateWidget(
                imagePath: AssetsConstants.noRatingFound,
                title: context.translate(LanguageLabelKeys.noReviewsFound),
                subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
              );
            }

            return RefreshIndicator(
              color: context.cs.primary,
              onRefresh: () => widget.args.ratingsCubit.loadRatings(
                productId: widget.args.productId,
              ),
              child: _pager.attach(
                ListView.builder(
                  controller: _pager.controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingL + context.bottomSafePadding,
                  ),
                  itemCount: state.data.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        margin: const EdgeInsetsDirectional.only(
                          bottom: ThemeConstants.paddingM,
                        ),
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: ThemeConstants.paddingM,
                        ),
                        decoration: BoxDecoration(
                          color: context.cs.surface,
                          border: Border.all(color: context.cs.outlineVariant),
                          borderRadius: AppRadius.r10,
                          boxShadow: [
                            BoxShadow(
                              color: context.theme.shadowColor.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ProductRatingSummaryHeader(
                          data: summary,
                          avgRating: avgRating,
                          total: total,
                        ),
                      );
                    }
                    final reviewIndex = index - 1;
                    if (reviewIndex == state.data.length) {
                      return PaginatedListFooter(
                        isLoadingMore: state.isFetchingMore,
                        hasMore: state.hasMore,
                      );
                    }
                    return ProductDetailReviewTile(
                      review: state.data[reviewIndex],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
