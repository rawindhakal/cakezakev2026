import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/features/products/cubit/similar_product_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_grid_section.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';

typedef _SimilarProductState = PaginationState<ProductDataModel>;
typedef _SimilarProductLoaded = PaginationLoaded<ProductDataModel>;

class SimilarProductsSection extends StatelessWidget {
  /// Scopes this section's hero tags (e.g. `product_hero_<id>_sp`) to the
  /// hosting product detail page, so concurrently-mounted pages in the
  /// swipeable pager never collide on the same tag.
  final String heroSuffix;
  final Key? sectionKey;

  const SimilarProductsSection({
    super.key,
    this.heroSuffix = '_sp',
    this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimilarProductCubit, _SimilarProductState>(
      builder: (context, state) {
        if (state is! _SimilarProductLoaded || state.data.isEmpty) {
          return const SizedBox.shrink();
        }
        return ProductGridSection(
          sectionKey: sectionKey,
          heroSuffix: heroSuffix,
          title: context.translate(LanguageLabelKeys.similarProducts),
          products: state.data,
          total: state.total,
        );
      },
    );
  }
}
