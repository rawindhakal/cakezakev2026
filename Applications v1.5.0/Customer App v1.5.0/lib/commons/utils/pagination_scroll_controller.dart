import 'package:flutter/widgets.dart';

/// Wraps a [ScrollController] with a near-bottom listener for pagination.
class PaginationScrollController {
  final ScrollController controller = ScrollController();
  final VoidCallback onLoadMore;

  /// Fraction of the scroll extent (0-1) after which [onLoadMore] fires.
  /// Default 0.7 triggers once 70% is scrolled (30% remaining).
  final double triggerFraction;

  PaginationScrollController({
    required this.onLoadMore,
    this.triggerFraction = 0.7,
  }) {
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!controller.hasClients) return;
    final max = controller.position.maxScrollExtent;
    if (max <= 0) return;
    if (controller.position.pixels >= max * triggerFraction) {
      onLoadMore();
    }
  }

  void _maybeLoadMore() {
    if (!controller.hasClients) return;
    if (controller.position.maxScrollExtent <= 0) {
      onLoadMore();
    }
  }

  /// Wrap the paginated scrollable with this so short lists (content that
  /// doesn't fill the viewport) still trigger [onLoadMore]. Without it,
  /// [_onScroll] never fires because there's nothing to scroll — pagination
  /// silently stalls until the user manually nudges the list.
  ///
  /// [ScrollMetricsNotification] bubbles whenever scroll metrics change,
  /// including right after first layout with no user interaction, so this
  /// needs no manual post-frame/hasMore bookkeeping at call sites — the
  /// underlying cubit already no-ops [onLoadMore] when a fetch isn't needed.
  Widget attach(Widget child) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _maybeLoadMore();
        return false;
      },
      child: child,
    );
  }

  void dispose() => controller.dispose();
}
