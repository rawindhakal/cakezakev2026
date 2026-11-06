import 'package:flutter/material.dart';

/// Scrolls [key]'s target into view, then flashes a soft highlight over
/// it — regardless of whether a scroll actually happened.
///
/// `Scrollable.ensureVisible` computes a zero delta when the target is
/// already inside the viewport (e.g. the user already scrolled to the
/// bottom), so without the flash the action silently appears to do nothing.
///
/// [key]'s target may not be mounted yet at call time — e.g. it sits behind
/// an async-loaded section (a BlocBuilder rendering `SizedBox.shrink()`
/// until its data arrives) that hasn't resolved by the moment the caller
/// fires this. Rather than silently no-op, this retries for [retryFor]
/// before giving up.
Future<void> ensureVisibleAndFlash(
  BuildContext context,
  GlobalKey key, {
  double alignment = 0.2,
  Color? color,
  Duration retryFor = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(retryFor);
  var ctx = key.currentContext;
  while (ctx == null) {
    if (!context.mounted || DateTime.now().isAfter(deadline)) return;
    await Future.delayed(const Duration(milliseconds: 150));
    ctx = key.currentContext;
  }
  if (!ctx.mounted) return;
  await Scrollable.ensureVisible(
    ctx,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    alignment: alignment,
  );
  if (!ctx.mounted) return;
  // The scroll animation's last frame and layout settling don't land in
  // the same microtask as this await — measuring immediately can grab a
  // stale position (the overlay ends up a frame off, above the tile).
  await WidgetsBinding.instance.endOfFrame;
  if (!ctx.mounted) return;

  final renderBox = ctx.findRenderObject() as RenderBox?;
  if (renderBox == null || !renderBox.attached) return;
  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;
  final flashColor = color ?? Theme.of(context).colorScheme.primary;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: position.dx,
      top: position.dy,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 1100),
          curve: const Interval(0.15, 1, curve: Curves.easeOut),
          builder: (_, value, _) => Transform.scale(
            scale: 1 + (0.03 * value),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: flashColor.withValues(alpha: value * 0.16),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  await Future.delayed(const Duration(milliseconds: 1100));
  entry.remove();
}
