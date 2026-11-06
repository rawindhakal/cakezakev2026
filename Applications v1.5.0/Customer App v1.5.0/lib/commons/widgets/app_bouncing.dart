import 'package:flutter/material.dart';

/// Scales [child] down slightly on tap-down and back up on release —
/// a tactile "bounce" used on product/category cards across the app.
class AppBouncing extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AppBouncing({super.key, required this.child, this.onTap});

  @override
  State<AppBouncing> createState() => _AppBouncingState();
}

class _AppBouncingState extends State<AppBouncing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _controller.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}
