import 'dart:math' as math;

import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/services/analytics_service.dart';
import 'package:customer/core/services/clarity_service.dart';
import 'package:customer/core/services/crashlytics_service.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/favourite/cubit/favorite_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FavoriteButtonStyle { plain, circle }

class FavoriteButton extends StatefulWidget {
  final String? productId;
  final bool initialIsFavorite;
  final double iconSize;
  final FavoriteButtonStyle style;

  /// circle style only: when true renders IconButton instead of container
  final bool isActive;

  /// Override default toggleById. Auth guard still applied before calling.
  final VoidCallback? onTap;

  const FavoriteButton({
    super.key,
    required this.productId,
    this.initialIsFavorite = false,
    this.iconSize = 20,
    this.style = FavoriteButtonStyle.plain,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final GlobalKey _iconKey = GlobalKey();

  void _handleTap(BuildContext context, bool isFav) {
    if (!AuthHiveBox.instance.isLoggedIn) {
      AppNavigator.pushNamed(context, RouteNames.login);
      return;
    }
    AppHaptics.tap();
    if (!isFav) {
      // Sprinkle burst only when marking as favorite — like Blinkit's heart
      // pop. Painted via the root Overlay (not a local Stack) so it's never
      // cut off by a clipped ancestor, e.g. a pinned SliverAppBar.
      _showSprinkleBurst(context);
    }
    _logToggle(widget.productId, !isFav);
    if (widget.onTap != null) {
      widget.onTap!();
    } else if (widget.productId != null) {
      try {
        context.read<FavoriteCubit>().toggleById(
          widget.productId!,
          fallback: widget.initialIsFavorite,
        );
      } catch (error, stack) {
        CrashlyticsService.instance.recordError(
          error,
          stack,
          reason: 'FavoriteButton.toggleById failed',
        );
      }
    }
  }

  void _logToggle(String? productId, bool isFavoriteNow) {
    AnalyticsService.instance.logEvent(
      AppConstants.eventToggleFavorite,
      parameters: {
        AppConstants.paramProductId: productId ?? 'unknown',
        AppConstants.paramIsFavorite: isFavoriteNow,
      },
    );
    ClarityService.sendCustomEvent(
      isFavoriteNow
          ? AppConstants.clarityEventFavoriteAdded
          : AppConstants.clarityEventFavoriteRemoved,
    );
  }

  void _showSprinkleBurst(BuildContext context) {
    final renderBox = _iconKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (renderBox == null || overlay == null || !renderBox.attached) return;

    final center = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SprinkleOverlay(
        center: center,
        baseRadius: widget.iconSize,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<FavoriteCubit, bool>(
      (c) => c.state.isFavorite(
        widget.productId,
        fallback: widget.initialIsFavorite,
      ),
    );
    final color = isFav
        ? context.cs.onSecondaryFixed
        : context.cs.onSurfaceVariant;
    final iconWidget = Stack(
      alignment: Alignment.center,
      children: [
        AppSvgIcon(
          AssetsConstants.favouriteActiveIcon,
          size: widget.iconSize,
          color: isFav
              ? context.cs.onSecondaryFixed
              : context.cs.onInverseSurface.withValues(alpha: 0.9),
          bakeTint: true,
        ),
        AppSvgIcon(
          AssetsConstants.favouriteIcon,
          size: widget.iconSize,
          color: color,
          bakeTint: true,
        ),
      ],
    );

    if (widget.style == FavoriteButtonStyle.circle) {
      if (widget.isActive) {
        return GestureDetector(
          key: _iconKey,
          onTap: () => _handleTap(context, isFav),
          child: SizedBox(
            width: widget.iconSize + 2,
            height: widget.iconSize + 2,
            child: FittedBox(child: iconWidget),
          ),
        );
      }
      return GestureDetector(
        key: _iconKey,
        onTap: () => _handleTap(context, isFav),
        child: Container(
          width: 38,
          height: 38,
          decoration: AppDecorations.box(
            color: context.cs.surface.withValues(alpha: 0.9),
            shape: .circle,
            boxShadow: [
              BoxShadow(
                color: context.cs.scrim.withValues(alpha: 0.12),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(child: iconWidget),
        ),
      );
    }

    return GestureDetector(
      key: _iconKey,
      onTap: () => _handleTap(context, isFav),
      child: iconWidget,
    );
  }
}

/// One-shot sprinkle burst, centered on [center] (global coordinates),
/// mounted directly in the root [Overlay] so it paints above everything —
/// including any clipped ancestor the button itself sits inside — and
/// removes itself via [onDone] once the animation finishes.
class _SprinkleOverlay extends StatefulWidget {
  final Offset center;
  final double baseRadius;
  final VoidCallback onDone;

  const _SprinkleOverlay({
    required this.center,
    required this.baseRadius,
    required this.onDone,
  });

  @override
  State<_SprinkleOverlay> createState() => _SprinkleOverlayState();
}

class _SprinkleOverlayState extends State<_SprinkleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _particles = _generateParticles();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_Particle> _generateParticles() {
    final rand = math.Random();
    return List.generate(10, (i) {
      final angle = (i * (360 / 10)) + rand.nextDouble() * 18 - 9;
      return _Particle(
        angleRad: angle * math.pi / 180,
        distance: 0.7 + rand.nextDouble() * 0.6,
        size: 2.0 + rand.nextDouble() * 1.6,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final burstExtent = widget.baseRadius * 2.6;
    return Positioned(
      left: widget.center.dx - burstExtent / 2,
      top: widget.center.dy - burstExtent / 2,
      width: burstExtent,
      height: burstExtent,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _SprinklePainter(
                particles: _particles,
                progress: _ctrl.value,
                baseRadius: widget.baseRadius,
                color: context.cs.onSecondaryFixed,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double angleRad;
  final double distance; // multiplier of baseRadius
  final double size;

  _Particle({
    required this.angleRad,
    required this.distance,
    required this.size,
  });
}

class _SprinklePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1
  final double baseRadius;
  final Color color;

  _SprinklePainter({
    required this.particles,
    required this.progress,
    required this.baseRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final travel = Curves.easeOut.transform(progress);

    for (final p in particles) {
      final dist = baseRadius * p.distance * travel;
      final offset =
          center +
          Offset(math.cos(p.angleRad) * dist, math.sin(p.angleRad) * dist);
      final paint = Paint()..color = color.withValues(alpha: fade);
      canvas.drawCircle(offset, p.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SprinklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
