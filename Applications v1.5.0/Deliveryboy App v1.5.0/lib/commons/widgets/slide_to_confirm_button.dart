import 'package:deliveryboy/commons/utils/app_haptics.dart';
import 'package:deliveryboy/commons/widgets/loading_widget.dart';
import 'dart:async';

import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class SlideToConfirmButton extends StatefulWidget {
  final String label;

  /// Called once the thumb reaches the end. May be async — the thumb stays at
  /// the end until it finishes, then snaps back unless [isLoading] took over.
  final FutureOr<void> Function()? onConfirm;
  final bool isLoading;

  const SlideToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirm,
    this.isLoading = false,
  });

  @override
  State<SlideToConfirmButton> createState() => _SlideToConfirmButtonState();
}

class _SlideToConfirmButtonState extends State<SlideToConfirmButton>
    with TickerProviderStateMixin {
  static const double _height = 58;
  static const double _thumbSize = 46;
  static const double _thumbPadding = 6;

  double _dragOffset = 0;
  bool _completed = false;

  late final AnimationController _snapBack;
  late final Animation<double> _snapAnimation;
  double _snapFrom = 0;

  late final AnimationController _hint;
  late final Animation<double> _hintAnimation;

  @override
  void initState() {
    super.initState();
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapAnimation = CurvedAnimation(parent: _snapBack, curve: Curves.easeOut);
    _snapBack.addListener(() {
      setState(() => _dragOffset = _snapFrom * (1 - _snapAnimation.value));
      _updateHint();
    });

    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _hintAnimation = CurvedAnimation(parent: _hint, curve: Curves.easeInOut);
    _updateHint();
  }

  @override
  void dispose() {
    _snapBack.dispose();
    _hint.dispose();
    super.dispose();
  }

  // Idle nudge that hints the thumb is draggable. Runs only while the button
  // sits untouched at the start; any drag, load, or completion stops it.
  void _updateHint() {
    final bool idle =
        widget.onConfirm != null &&
        !widget.isLoading &&
        !_completed &&
        _dragOffset == 0;
    if (idle && !_hint.isAnimating) {
      _hint.repeat(reverse: true);
    } else if (!idle && _hint.isAnimating) {
      _hint.stop();
      _hint.value = 0;
    }
  }

  double _maxDrag(double trackWidth) =>
      trackWidth - _thumbSize - _thumbPadding * 2;

  void _onDragUpdate(double delta, double trackWidth) {
    if (widget.onConfirm == null || widget.isLoading || _completed) return;
    _snapBack.stop();
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0, _maxDrag(trackWidth));
    });
    _updateHint();
    if (_dragOffset >= _maxDrag(trackWidth)) unawaited(_complete());
  }

  void _onDragEnd(double trackWidth) {
    if (_completed) return;
    _snapToStart();
  }

  void _snapToStart() {
    _snapFrom = _dragOffset;
    _snapBack.forward(from: 0);
  }

  Future<void> _complete() async {
    if (_completed) return;
    setState(() => _completed = true);
    AppHaptics.impact();
    _updateHint();
    final result = widget.onConfirm?.call();
    if (result is Future<void>) await result;
    // The callback may end without starting any work (e.g. the OTP sheet was
    // dismissed), leaving the thumb stuck at the end — snap it back so the
    // button is usable again. When work did start, isLoading owns the reset.
    if (!mounted || widget.isLoading) return;
    setState(() => _completed = false);
    _snapToStart();
    _updateHint();
  }

  @override
  void didUpdateWidget(SlideToConfirmButton old) {
    super.didUpdateWidget(old);
    if (old.isLoading && !widget.isLoading) {
      setState(() => _completed = false);
      _snapToStart();
    }
    _updateHint();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onConfirm == null;
    return LayoutBuilder(
      builder: (_, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = _maxDrag(trackWidth);
        final clampedOffset = _dragOffset.clamp(0.0, maxDrag);
        final progress = maxDrag > 0 ? (clampedOffset / maxDrag) : 0.0;

        final isRtl = Directionality.of(context) == TextDirection.rtl;
        return GestureDetector(
          onHorizontalDragUpdate: disabled || widget.isLoading
              ? null
              : (d) =>
                    _onDragUpdate(isRtl ? -d.delta.dx : d.delta.dx, trackWidth),
          onHorizontalDragEnd: disabled || widget.isLoading
              ? null
              : (_) => _onDragEnd(trackWidth),
          child: Container(
            height: _height,
            width: double.infinity,
            decoration: AppDecorations.card(
              borderRadius: BorderRadius.circular(_height / 2),
              gradient: LinearGradient(
                colors: [
                  disabled
                      ? context.cs.primary.withValues(alpha: 0.5)
                      : context.cs.primary,
                  disabled
                      ? context.cs.primary.withValues(alpha: 0.5)
                      : Color.lerp(
                          context.cs.primary,
                          context.cs.primary,
                          progress,
                        )!,
                ],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
              border: Border.all(color: context.cs.primary, width: 2),
            ),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                // Label — fades out as thumb nears end
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: _thumbSize + _thumbPadding * 2,
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: (1 - progress * 1.5).clamp(0.0, 1.0),
                        child: AppText(
                          widget.label,
                          style: context.tt.displayMedium?.copyWith(
                            color: context.cs.onPrimary,
                            letterSpacing: 0.3,
                          ),
                          overflow: .ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thumb — nudges right on an idle loop to hint it's draggable
                AnimatedBuilder(
                  animation: _hintAnimation,
                  builder: (_, child) => PositionedDirectional(
                    start:
                        _thumbPadding +
                        clampedOffset +
                        _hintAnimation.value * 10,
                    child: child!,
                  ),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: AppDecorations.circle(
                      color: context.cs.onPrimary,
                      boxShadow: [
                        BoxShadow(
                          color: context.cs.shadow.withValues(alpha: 0.16),
                          blurRadius: 6,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: widget.isLoading
                        ? const Padding(
                            padding: EdgeInsetsDirectional.all(
                              ThemeConstants.paddingM,
                            ),
                            child: LoadingWidget(
                              size: ThemeConstants.loaderSize,
                            ),
                          )
                        : Transform.flip(
                            flipX:
                                Directionality.of(context) == TextDirection.rtl,
                            child: AppSvgIcon(
                              AssetsConstants.arrowRightIcon,
                              color: context.cs.primary,
                              size: ThemeConstants.iconL,
                              fit: BoxFit.scaleDown,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
