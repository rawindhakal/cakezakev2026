import 'dart:math';

import 'package:customer/features/splash/widgets/ultra_painter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

class UltraLoader extends StatefulWidget {
  final double size;
  const UltraLoader({super.key, this.size = 55});

  @override
  State<UltraLoader> createState() => _UltraLoaderState();
}

class _UltraLoaderState extends State<UltraLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          return Transform.rotate(
            angle: _controller.value * 2 * pi,
            child: CustomPaint(
              painter: UltraPainter(color: context.cs.onPrimary),
            ),
          );
        },
      ),
    );
  }
}
