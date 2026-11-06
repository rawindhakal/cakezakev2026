import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/cubit/cart_recommendations_cubit.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';

class CheckoutRecommendationsSection extends StatelessWidget {
  const CheckoutRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartRecommendationsCubit, CartRecommendationsState>(
      builder: (context, state) {
        if (state is! CartRecommendationsLoaded) return const SizedBox.shrink();
        final crossSell = state.recommendations.data?.crossSell?.products ?? [];
        final upsell = state.recommendations.data?.upsell?.products ?? [];

        return Column(
          crossAxisAlignment: .start,
          children: [
            if (crossSell.isNotEmpty) ...[
              _RecommendationRow(
                title: context.translate(
                  LanguageLabelKeys.frequentlyBoughtTogether,
                ),
                products: crossSell,
                heroSuffix: '_cross_sell',
                hasMore: state.hasMoreCrossSell,
                isLoadingMore: state.isLoadingMoreCrossSell,
                onLoadMore: () => context
                    .read<CartRecommendationsCubit>()
                    .loadMoreCrossSell(),
              ),
              AppSpacing.h12,
            ],
            if (upsell.isNotEmpty) ...[
              _RecommendationRow(
                title: context.translate(LanguageLabelKeys.upgradeYourOrder),
                products: upsell,
                heroSuffix: '_upsell',
                hasMore: state.hasMoreUpsell,
                isLoadingMore: state.isLoadingMoreUpsell,
                onLoadMore: () =>
                    context.read<CartRecommendationsCubit>().loadMoreUpsell(),
              ),
              AppSpacing.h12,
            ],
          ],
        );
      },
    );
  }
}

class _RecommendationRow extends StatefulWidget {
  const _RecommendationRow({
    required this.title,
    required this.products,
    required this.heroSuffix,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final String title;
  final List<ProductDataModel> products;
  final String heroSuffix;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  State<_RecommendationRow> createState() => _RecommendationRowState();
}

class _RecommendationRowState extends State<_RecommendationRow> {
  late final _pager = PaginationScrollController(
    onLoadMore: () {
      if (!widget.hasMore || widget.isLoadingMore) return;
      widget.onLoadMore();
    },
  );

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingM,
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingM,
            ),
            child: AppText(
              widget.title,
              style: context.tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              const listPadding = ThemeConstants.paddingM;
              final visibleCount = AppSizes.isTablet(context) ? 4 : 3;
              final itemWidth =
                  (constraints.maxWidth -
                      listPadding * 2 -
                      gap * (visibleCount - 1)) /
                  visibleCount;
              final itemCount =
                  widget.products.length + (widget.isLoadingMore ? 1 : 0);
              return SizedBox(
                height: 265,
                child: _pager.attach(
                  ListView.separated(
                    controller: _pager.controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: listPadding,
                    ),
                    itemCount: itemCount,
                    separatorBuilder: (_, _) => AppSpacing.w10,
                    itemBuilder: (context, i) {
                      if (i >= widget.products.length) {
                        return SizedBox(
                          width: itemWidth,
                          child: const ProductCardSkeleton(),
                        );
                      }
                      return SizedBox(
                        width: itemWidth,
                        child: ProductCard(
                          product: widget.products[i],
                          heroSuffix: widget.heroSuffix,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
