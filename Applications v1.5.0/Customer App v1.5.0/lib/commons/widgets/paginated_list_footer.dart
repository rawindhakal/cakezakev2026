import 'package:flutter/material.dart';
import 'loading_widget.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Shows a skeleton (if [skeletonBuilder] given) or loading spinner while
/// paginating, nothing otherwise.
class PaginatedListFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;
  final WidgetBuilder? skeletonBuilder;

  const PaginatedListFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
    this.skeletonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      if (skeletonBuilder != null) {
        return skeletonBuilder!(context);
      }
      return const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          vertical: ThemeConstants.paddingL,
        ),
        child: Center(child: LoadingWidget(size: ThemeConstants.loaderSize)),
      );
    }
    return const SizedBox.shrink();
  }
}
