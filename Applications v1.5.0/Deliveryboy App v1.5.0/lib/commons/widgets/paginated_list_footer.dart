import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Shows a skeleton placeholder, or nothing, at the bottom of a paginated list.
class PaginatedListFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;

  const PaginatedListFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(
          bottom: ThemeConstants.paddingM,
        ),
        child: ShimmerLoading(
          child: ShimmerBox(height: context.screenHeight * 0.113),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
