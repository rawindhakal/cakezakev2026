import 'dart:math' as math;

import 'package:customer/commons/widgets/wave_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/favourite/cubit/favorite_cubit.dart';
import 'package:customer/features/products/widgets/product_card.dart';
import 'package:customer/features/products/widgets/product_card_details.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontal "Your Wishlist" row on the search screen's default view.
/// Logged-in only, and hidden while the favourites list is empty.
class SearchWishlistSection extends StatelessWidget {
  const SearchWishlistSection({super.key, this.titleKey});

  /// Remounts the title's WaveText to replay it, same as the sibling titles.
  final Key? titleKey;

  static const String _heroSuffix = '_wl';

  @override
  Widget build(BuildContext context) {
    if (!AuthHiveBox.instance.isLoggedIn) return const SizedBox.shrink();
    return BlocBuilder<FavoriteCubit, FavoriteState>(
      buildWhen: (prev, next) => prev.products != next.products,
      builder: (context, state) {
        final products = state.products;
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ThemeConstants.paddingL,
                end: ThemeConstants.paddingL,
                top: ThemeConstants.paddingXL,
                bottom: ThemeConstants.paddingM,
              ),
              child: WaveText(
                key: titleKey,
                context.translate(
                  LanguageLabelKeys.yourWishlist,
                  fallback: 'Your Wishlist',
                ),
                style: context.tt.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Same card width/gap as the "What's on your mind" grid below
                // (ProductListingView: 3/5 columns, 10px gap, paddingL sides).
                final isTablet = AppSizes.isTablet(context);
                final gap = 10 * (isTablet ? 1.75 : 1.0);
                final columns = isTablet ? 5 : 3;
                final itemWidth =
                    (constraints.maxWidth -
                        ThemeConstants.paddingL * 2 -
                        gap * (columns - 1)) /
                    columns;
                // Tallest details block so every card shares one height.
                final textWidth = math.max(0.0, itemWidth - 20);
                final minDetailsHeight = products.fold<double>(
                  0,
                  (max, p) => math.max(
                    max,
                    ProductCardDetails.estimateHeight(context, p, textWidth),
                  ),
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingL,
                  ),
                  child: Row(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: List.generate(
                      products.length,
                      (i) => Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: i == products.length - 1 ? 0 : gap,
                        ),
                        child: SizedBox(
                          width: itemWidth,
                          child: ProductCard(
                            key: ValueKey(products[i].id),
                            product: products[i],
                            heroSuffix: _heroSuffix,
                            siblingProducts: products,
                            index: i,
                            cardWidth: itemWidth,
                            minDetailsHeight: minDetailsHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
