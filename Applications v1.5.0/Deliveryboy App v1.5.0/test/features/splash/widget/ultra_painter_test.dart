import 'dart:math';

import 'package:deliveryboy/features/splash/widget/ultra_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_logging.dart';

/// `UltraPainter` is pure geometry with no widget around it, so it is driven
/// against a recording `Canvas` rather than a pumped widget — that is the only
/// way to read back the three arcs (base ring, dim trailing arc, bright head)
/// and their paints, which no finder can see once they are rasterized.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  const color = Color(0xFF123456);
  const size = Size(55, 55);

  _RecordingCanvas paint() {
    final canvas = _RecordingCanvas();
    UltraPainter(color: color).paint(canvas, size);
    return canvas;
  }

  test('draws exactly three arcs — base ring, trailing arc, bright head', () {
    printTestDivider('UltraPainter draws exactly three arcs');
    final canvas = paint();

    printTestLog('arcs → expected: 3, actual: ${canvas.arcs.length}');
    expect(canvas.arcs.length, 3);
  });

  test('insets every arc by the 4px padding', () {
    printTestDivider('UltraPainter insets every arc by the 4px padding');
    final canvas = paint();
    const expected = Rect.fromLTWH(4, 4, 47, 47);

    for (final arc in canvas.arcs) {
      printTestLog('rect → expected: $expected, actual: ${arc.rect}');
      expect(arc.rect, expected);
    }
  });

  test('the base ring is a full, barely-visible circle', () {
    printTestDivider('UltraPainter the base ring is a full circle');
    final base = paint().arcs[0];

    printTestLog('start → expected: 0, actual: ${base.startAngle}');
    expect(base.startAngle, 0);
    printTestLog('sweep → expected: ${2 * pi}, actual: ${base.sweepAngle}');
    expect(base.sweepAngle, closeTo(2 * pi, 1e-9));
    printTestLog('alpha → expected: 0.06, actual: ${base.paint.color.a}');
    expect(base.paint.color.a, closeTo(0.06, 0.001));
    printTestLog('style → expected: stroke, actual: ${base.paint.style}');
    expect(base.paint.style, PaintingStyle.stroke);
    printTestLog('strokeWidth → expected: 7.0, actual: ${base.paint.strokeWidth}');
    expect(base.paint.strokeWidth, 7.0);
  });

  test('the trailing arc starts at 12 o\'clock and sweeps 1.3π, dimmed', () {
    printTestDivider('UltraPainter the trailing arc sweeps 1.3pi, dimmed');
    final dark = paint().arcs[1];

    printTestLog('start → expected: ${-pi / 2}, actual: ${dark.startAngle}');
    expect(dark.startAngle, closeTo(-pi / 2, 1e-9));
    printTestLog('sweep → expected: ${1.3 * pi}, actual: ${dark.sweepAngle}');
    expect(dark.sweepAngle, closeTo(1.3 * pi, 1e-9));
    printTestLog('alpha → expected: 0.15, actual: ${dark.paint.color.a}');
    expect(dark.paint.color.a, closeTo(0.15, 0.001));
    printTestLog('cap → expected: round, actual: ${dark.paint.strokeCap}');
    expect(dark.paint.strokeCap, StrokeCap.round);
  });

  test('the bright head picks up where the trailing arc ends, at full alpha', () {
    printTestDivider('UltraPainter the bright head follows the trailing arc');
    final arcs = paint().arcs;
    final dark = arcs[1];
    final bright = arcs[2];

    printTestLog(
      'start → expected: ${dark.startAngle + dark.sweepAngle}, actual: ${bright.startAngle}',
    );
    expect(bright.startAngle, closeTo(dark.startAngle + dark.sweepAngle, 1e-9));
    printTestLog('sweep → expected: ${0.5 * pi}, actual: ${bright.sweepAngle}');
    expect(bright.sweepAngle, closeTo(0.5 * pi, 1e-9));
    // Compared as packed ARGB: Paint round-trips the color through floats, so
    // the Color instances are not `==` even though every channel matches.
    printTestLog(
      'color → expected: ${color.toARGB32()}, actual: ${bright.paint.color.toARGB32()}',
    );
    expect(bright.paint.color.toARGB32(), color.toARGB32());
    printTestLog('cap → expected: round, actual: ${bright.paint.strokeCap}');
    expect(bright.paint.strokeCap, StrokeCap.round);
  });

  test('no arc is drawn with a center wedge', () {
    printTestDivider('UltraPainter no arc is drawn with a center wedge');
    for (final arc in paint().arcs) {
      printTestLog('useCenter → expected: false, actual: ${arc.useCenter}');
      expect(arc.useCenter, isFalse);
    }
  });

  test('scales the ring with the canvas', () {
    printTestDivider('UltraPainter scales the ring with the canvas');
    final canvas = _RecordingCanvas();
    UltraPainter(color: color).paint(canvas, const Size(100, 80));

    const expected = Rect.fromLTWH(4, 4, 92, 72);
    printTestLog('rect → expected: $expected, actual: ${canvas.arcs.first.rect}');
    expect(canvas.arcs.first.rect, expected);
  });

  test('always repaints — the loader rotates every frame', () {
    printTestDivider('UltraPainter always repaints');
    final painter = UltraPainter(color: color);

    printTestLog(
      'shouldRepaint(same color) → expected: true, '
      'actual: ${painter.shouldRepaint(UltraPainter(color: color))}',
    );
    expect(painter.shouldRepaint(UltraPainter(color: color)), isTrue);
  });
}

class _RecordedArc {
  final Rect rect;
  final double startAngle;
  final double sweepAngle;
  final bool useCenter;
  final Paint paint;

  _RecordedArc(
    this.rect,
    this.startAngle,
    this.sweepAngle,
    this.useCenter,
    this.paint,
  );
}

/// Canvas stand-in that records `drawArc` calls and ignores everything else.
class _RecordingCanvas implements Canvas {
  final List<_RecordedArc> arcs = [];

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) {
    arcs.add(_RecordedArc(rect, startAngle, sweepAngle, useCenter, paint));
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}
