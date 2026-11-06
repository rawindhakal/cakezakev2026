import 'package:customer/features/products/cubit/recently_visited_cubit.dart';
import 'package:customer/features/products/widgets/product_grid_section.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';

class RecentlyVisitedSection extends StatelessWidget {
  /// Scopes this section's hero tags (e.g. `product_hero_<id>_rv`) to the
  /// hosting product detail page, so concurrently-mounted pages in the
  /// swipeable pager never collide on the same tag.
  final String heroSuffix;
  final Key? sectionKey;

  const RecentlyVisitedSection({
    super.key,
    this.heroSuffix = '_rv',
    this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecentlyVisitedCubit, RecentlyVisitedState>(
      builder: (context, state) {
        if (state is! RecentlyVisitedLoaded || state.products.isEmpty) {
          return const SizedBox.shrink();
        }
        return ProductGridSection(
          sectionKey: sectionKey,
          heroSuffix: heroSuffix,
          title: context.translate(LanguageLabelKeys.recentlyVisited),
          products: state.products,
          total: state.total,
          mainAxisSpacing: 16,
        );
      },
    );
  }
}
