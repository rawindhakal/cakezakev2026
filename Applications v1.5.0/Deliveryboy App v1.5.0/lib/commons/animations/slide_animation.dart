import 'package:flutter/material.dart';

enum SlideDirection { fromTop, fromLeft, fromRight, fromBottom }

/// Default entrance duration shared by every staggered slide-in.
const Duration _defaultSlideDuration = Duration(milliseconds: 600);

/// Owns the [AnimationController] that drives a staggered [SlideAnimation] run
/// and hands it to [builder]. Use it when the animated items come from a
/// [ListView.builder] or any other dynamic list — for a fixed set of children
/// prefer [SlideAnimationList].
class SlideAnimationScope extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context, AnimationController controller)
  builder;

  const SlideAnimationScope({
    super.key,
    required this.builder,
    this.duration = _defaultSlideDuration,
  });

  @override
  State<SlideAnimationScope> createState() => _SlideAnimationScopeState();
}

class _SlideAnimationScopeState extends State<SlideAnimationScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _animationController);
}

/// Drop-in replacement for a [Column] whose children slide and fade in one
/// after another — the entrance used by the bottom sheets across the app.
class SlideAnimationList extends StatelessWidget {
  final List<Widget> children;
  final SlideDirection slideDirection;
  final Duration duration;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const SlideAnimationList({
    super.key,
    required this.children,
    this.slideDirection = SlideDirection.fromBottom,
    this.duration = _defaultSlideDuration,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return SlideAnimationScope(
      duration: duration,
      builder: (context, controller) => Column(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        spacing: spacing,
        children: [
          for (var i = 0; i < children.length; i++)
            SlideAnimation(
              position: i,
              itemCount: children.length,
              slideDirection: slideDirection,
              animationController: controller,
              child: children[i],
            ),
        ],
      ),
    );
  }
}

class SlideAnimation extends StatefulWidget {
  final int position;
  final int itemCount;
  final Widget? child;
  final SlideDirection slideDirection;
  final AnimationController? animationController;

  // we have created a named parameter constructor
  const SlideAnimation({
    super.key,
    required this.position,
    required this.itemCount,
    required this.slideDirection,
    required this.animationController,
    required this.child,
  });

  @override
  State<SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<SlideAnimation> {
  @override
  Widget build(BuildContext context) {
    // we need x and y translation variables to animate items in different direction using our enum
    var xTranslation = 0.0, yTranslation = 0.0;

    // we need to declare our animation for fade transition widget
    var animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.animationController!,
        // curve for the way you want to animate your list item widget. you can use anything from curves
        curve: Interval(
          (1 / widget.itemCount) * widget.position,
          1.0,
          curve: Curves.fastOutSlowIn,
        ),
      ),
    );

    widget.animationController!.forward();

    return AnimatedBuilder(
      animation: widget.animationController!,
      builder: (context, child) {
        if (widget.slideDirection == SlideDirection.fromTop) {
          // this will animate items from top with fade transition
          yTranslation = -50 * (1.0 - animation.value);
        } else if (widget.slideDirection == SlideDirection.fromBottom) {
          // this will animate items from bottom with fade transition
          yTranslation = 50 * (1.0 - animation.value);
        } else if (widget.slideDirection == SlideDirection.fromRight) {
          // this will animate items from right with fade transition
          xTranslation = 400 * (1.0 - animation.value);
        } else {
          // this will animate items from left with fade transition
          xTranslation = -400 * (1.0 - animation.value);
        }

        return FadeTransition(
          opacity: animation,
          child: Transform(
            transform: Matrix4.translationValues(
              xTranslation,
              yTranslation,
              0.0,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
