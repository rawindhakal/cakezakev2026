import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Per-letter sine bob-bounce, staggered left to right, played 3x back to
/// back (900ms each, 1200ms gap) on mount. Give it a new [Key] (e.g.
/// `ValueKey(counter)`) to force a remount and replay the sequence.
class WaveText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const WaveText(this.text, {super.key, this.style});

  @override
  State<WaveText> createState() => _WaveTextState();
}

class _WaveTextState extends State<WaveText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  Future<void> _startAnimation() async {
    if (_isAnimating) return;
    _isAnimating = true;

    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      await _controller.forward(from: 0);
      if (!mounted) return;
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    _isAnimating = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.text.length, (index) {
            final delay = index * 0.035;
            var progress = (_controller.value - delay) / 0.35;
            progress = progress.clamp(0.0, 1.0);
            final bounce = math.sin(progress * math.pi) * 5;
            return Transform.translate(
              offset: Offset(0, -bounce),
              child: Text(widget.text[index], style: widget.style),
            );
          }),
        );
      },
    );
  }
}
