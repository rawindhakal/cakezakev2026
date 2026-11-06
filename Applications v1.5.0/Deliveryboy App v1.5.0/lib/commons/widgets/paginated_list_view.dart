import 'package:flutter/material.dart';
import '../../utils/extensions/context_extensions.dart';
import 'paginated_list_footer.dart';

/// Generic pull-to-refresh, infinite-scroll list: renders [itemBuilder] for
/// each item plus a trailing [PaginatedListFooter] slot for the loading skeleton.
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

  /// Optional widget rendered as the first list item (scrolls with the list).
  final Widget? header;

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
    this.header,
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
        itemCount: items.length + (header != null ? 1 : 0) + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, rawIndex) {
          if (header != null && rawIndex == 0) return header;
          final index = header != null ? rawIndex - 1 : rawIndex;
          if (index == items.length) {
            return PaginatedListFooter(
              isLoadingMore: isLoadingMore,
              hasMore: hasMore,
            );
          }
          return itemBuilder(context, items[index], index);
        },
      ),
    );
  }
}
