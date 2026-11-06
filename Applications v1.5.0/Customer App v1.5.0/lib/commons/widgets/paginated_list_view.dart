import 'package:flutter/material.dart';
import '../../utils/extensions/context_extensions.dart';
import 'paginated_list_footer.dart';

/// Generic pull-to-refresh, infinite-scroll list: renders [itemBuilder] for
/// each item plus a trailing [PaginatedListFooter] slot for the loading spinner.
class PaginatedListView<T> extends StatelessWidget {
  final List<T> items;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final Color? refreshBackgroundColor;
  final double refreshStrokeWidth;
  final WidgetBuilder? loadingMoreSkeletonBuilder;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onRefresh,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.refreshBackgroundColor,
    this.refreshStrokeWidth = 2.0,
    this.loadingMoreSkeletonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.cs.primary,
      backgroundColor: refreshBackgroundColor,
      strokeWidth: refreshStrokeWidth,
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return PaginatedListFooter(
              isLoadingMore: isLoadingMore,
              hasMore: hasMore,
              skeletonBuilder: loadingMoreSkeletonBuilder,
            );
          }
          return itemBuilder(context, items[index], index);
        },
      ),
    );
  }
}
