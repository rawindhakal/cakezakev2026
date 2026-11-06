import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_view.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Shared paginated-list shell used by the Quick Order, Ecommerce and Return
/// Request tabs. Callers own their item type, card widget and navigation —
/// this only wires up the empty state and the common padding/scroll plumbing.
class OrderListView<T> extends StatelessWidget {
  final List<T> items;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyImagePath;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollPhysics? physics;

  const OrderListView({
    super.key,
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyImagePath,
    required this.itemBuilder,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        imagePath: emptyImagePath,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return PaginatedListView<T>(
      items: items,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      scrollController: scrollController,
      onRefresh: onRefresh,
      physics: physics,
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingS + context.bottomSafePadding,
      ),
      itemBuilder: itemBuilder,
    );
  }
}
