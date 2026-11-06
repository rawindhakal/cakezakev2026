import 'package:flutter/widgets.dart';

/// Wraps a [ScrollController] with a near-bottom listener that fires
/// [onLoadMore] once the user scrolls past [triggerFraction] of the
/// scroll extent (default 0.7 — triggers with 30% left to scroll).
/// Create in `initState` (needs `context`/cubit access in [onLoadMore]),
/// dispose in `dispose`.
class PaginationScrollController {
  final ScrollController controller = ScrollController();
  final VoidCallback onLoadMore;
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

  void dispose() => controller.dispose();
}
