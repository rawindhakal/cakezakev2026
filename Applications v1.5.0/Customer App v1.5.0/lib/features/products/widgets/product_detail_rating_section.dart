import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/star_rating_row.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/products/cubit/rating_images_cubit.dart';
import 'package:customer/features/products/cubit/ratings_list_cubit.dart';
import 'package:customer/features/products/models/product_rating_model.dart';
import 'package:customer/features/products/screens/product_all_reviews_screen.dart';
import 'package:customer/features/products/widgets/view_more_button.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

typedef _RatingImagesState = PaginationState<String>;
typedef _RatingImagesLoaded = PaginationLoaded<String>;
typedef _RatingsListState = PaginationState<ProductRatingList>;
typedef _RatingsListLoaded = PaginationLoaded<ProductRatingList>;

class ProductDetailRatingSection extends StatelessWidget {
  final bool? productRating;

  const ProductDetailRatingSection({super.key, this.productRating});

  @override
  Widget build(BuildContext context) {
    if (productRating != true) return const SizedBox.shrink();

    return BlocBuilder<RatingsListCubit, _RatingsListState>(
      builder: (context, ratingsState) {
        if (ratingsState is! _RatingsListLoaded) return const SizedBox.shrink();

        final data = context.read<RatingsListCubit>().summary;
        final ratingList = ratingsState.data;
        final avgRating = double.tryParse(data.averageRating ?? '0') ?? 0.0;
        final total =
            (int.tryParse(data.oneStarRating ?? '0') ?? 0) +
            (int.tryParse(data.twoStarRating ?? '0') ?? 0) +
            (int.tryParse(data.threeStarRating ?? '0') ?? 0) +
            (int.tryParse(data.fourStarRating ?? '0') ?? 0) +
            (int.tryParse(data.fiveStarRating ?? '0') ?? 0);

        if (total == 0) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
            vertical: ThemeConstants.paddingS,
          ),
          decoration: AppDecorations.shadowedCard(
            color: context.cs.surface,
            shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingM,
                ),
                child: AppText(
                  context.translate(LanguageLabelKeys.ratingsAndReviews),
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                  ),
                ),
              ),
              ProductRatingSummaryHeader(
                data: data,
                avgRating: avgRating,
                total: total,
              ),
              BlocBuilder<RatingImagesCubit, _RatingImagesState>(
                builder: (context, imgState) {
                  if (imgState is! _RatingImagesLoaded ||
                      imgState.data.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final photoSize = context.screenWidth * 0.2;
                  return Column(
                    crossAxisAlignment: .start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingL,
                          0,
                          ThemeConstants.paddingL,
                          ThemeConstants.paddingS,
                        ),
                        child: AppText(
                          context.translate(LanguageLabelKeys.photos),
                          style: context.tt.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: photoSize,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: ThemeConstants.paddingL,
                          ),
                          itemCount: imgState.data.length,
                          separatorBuilder: (_, _) => AppSpacing.w8,
                          itemBuilder: (_, i) => AppNetworkImage(
                            borderRadius: AppRadius.r8,
                            url: imgState.data[i],
                            width: photoSize,
                            height: photoSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      AppSpacing.h12,
                    ],
                  );
                },
              ),
              if (ratingList.isNotEmpty) ...[
                Divider(color: context.cs.outlineVariant, height: 1),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingM,
                    ThemeConstants.paddingL,
                    0,
                  ),
                  child: AppText(
                    '${context.translate(LanguageLabelKeys.customerReviews)} ($total)',
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
                AppSpacing.h12,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingL,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: .stretch,
                      children: [
                        for (final r in ratingList)
                          ProductDetailReviewTile(
                            review: r,
                            cardWidth: context.screenWidth * 0.72,
                          ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.h12,
                ViewMoreButton(
                  products: const [],
                  label: context.translate(LanguageLabelKeys.viewAllReviews),
                  horizontalMargin: ThemeConstants.paddingL,
                  onTap: () => Navigator.pushNamed(
                    context,
                    RouteNames.productAllReviews,
                    arguments: ProductAllReviewsArgs(
                      productId: context
                          .read<RatingsListCubit>()
                          .currentFilters,
                      ratingsCubit: context.read<RatingsListCubit>(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ProductRatingSummaryHeader extends StatelessWidget {
  final ProductRatingData data;
  final double avgRating;
  final int total;

  const ProductRatingSummaryHeader({
    super.key,
    required this.data,
    required this.avgRating,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        0,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
      ),
      child: Row(
        crossAxisAlignment: .center,
        children: [
          Column(
            children: [
              AppText(
                avgRating.toStringAsFixed(1),
                style: context.tt.displaySmall?.copyWith(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: context.cs.onSurface,
                  height: 1,
                ),
              ),
              AppSpacing.h4,
              ProductDetailStarRow(
                rating: avgRating,
                size: ThemeConstants.iconXS,
              ),
              AppSpacing.h4,
              AppText(
                '$total ${context.translate(LanguageLabelKeys.ratings)}',
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.w20,
          Expanded(
            child: Column(
              children: [
                ProductDetailRatingBar(
                  label: '5',
                  count: int.tryParse(data.fiveStarRating ?? '0') ?? 0,
                  total: total,
                ),
                ProductDetailRatingBar(
                  label: '4',
                  count: int.tryParse(data.fourStarRating ?? '0') ?? 0,
                  total: total,
                ),
                ProductDetailRatingBar(
                  label: '3',
                  count: int.tryParse(data.threeStarRating ?? '0') ?? 0,
                  total: total,
                ),
                ProductDetailRatingBar(
                  label: '2',
                  count: int.tryParse(data.twoStarRating ?? '0') ?? 0,
                  total: total,
                ),
                ProductDetailRatingBar(
                  label: '1',
                  count: int.tryParse(data.oneStarRating ?? '0') ?? 0,
                  total: total,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailStarRow extends StatelessWidget {
  final double rating;
  final double size;
  const ProductDetailStarRow({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return StarRatingRow(
      rating: rating,
      size: size,
      outlineColor: context.cs.outlineVariant,
      halfThreshold: 0,
    );
  }
}

class ProductDetailRatingBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  const ProductDetailRatingBar({
    super.key,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        children: [
          AppText(
            label,
            style: context.tt.labelSmall?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.w4,
          AppSvgIcon(
            AssetsConstants.starFillIcon,
            size: ThemeConstants.iconXXS,
            color: context.cs.onPrimaryFixedVariant,
          ),
          AppSpacing.w6,
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.r4,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: context.cs.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(context.cs.primary),
              ),
            ),
          ),
          AppSpacing.w6,
          SizedBox(
            width: 24,
            child: AppText(
              '$count',
              style: context.tt.labelSmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
              textAlign: .end,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailReviewTile extends StatefulWidget {
  final ProductRatingList review;
  // Fixed width for the horizontal preview strip's cards. Leave null for a
  // full-width card (used in the paginated all-reviews list) — either way
  // the card border/decoration stays the same.
  final double? cardWidth;

  const ProductDetailReviewTile({
    super.key,
    required this.review,
    this.cardWidth,
  });

  @override
  State<ProductDetailReviewTile> createState() =>
      _ProductDetailReviewTileState();
}

class _ProductDetailReviewTileState extends State<ProductDetailReviewTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final reviewImgSize = context.screenWidth * 0.16;
    final rating = double.tryParse(review.rate ?? '0') ?? 0.0;
    final name = review.user?.name ?? '';
    final reviewText = review.review ?? '';
    final date = review.updatedAt ?? '';
    final images = review.images ?? [];

    return Container(
      width: widget.cardWidth ?? double.infinity,
      margin: widget.cardWidth != null
          ? const EdgeInsetsDirectional.only(end: ThemeConstants.paddingM)
          : const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingM),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border.all(color: context.cs.outlineVariant),
        borderRadius: AppRadius.r10,
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Row(
                mainAxisSize: .min,
                children: [
                  ProductDetailStarRow(
                    rating: rating,
                    size: ThemeConstants.iconXS,
                  ),
                  AppSpacing.w4,
                  AppText(
                    rating.toStringAsFixed(1),
                    style: context.tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                ],
              ),
              if (date.isNotEmpty && date != 'null')
                AppText(
                  AppDateFormatter.formatDateTime(date.split(' ').first),
                  style: context.tt.labelSmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (reviewText.isNotEmpty && reviewText != 'null') ...[
            AppSpacing.h8,
            AppText(
              reviewText,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.onSurface,
                height: 1.5,
              ),
            ),
            if (reviewText.length > 90)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: AppText(
                    _expanded
                        ? context.translate(LanguageLabelKeys.readLess)
                        : context.translate(LanguageLabelKeys.readMore),
                    style: context.tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.primary,
                    ),
                  ),
                ),
              ),
          ],
          if (images.isNotEmpty) ...[
            AppSpacing.h10,
            SizedBox(
              height: reviewImgSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => AppSpacing.w6,
                itemBuilder: (_, i) => AppNetworkImage(
                  borderRadius: AppRadius.r6,
                  url: images[i].imageUrl ?? '',
                  width: reviewImgSize,
                  height: reviewImgSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          AppSpacing.h8,
          if (name.isNotEmpty)
            Row(
              mainAxisSize: .min,
              children: [
                AppSvgIcon(
                  AssetsConstants.checkCircleIcon,
                  size: ThemeConstants.iconXXS,
                  color: context.cs.primary,
                ),
                AppSpacing.w4,
                AppText(
                  name,
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
