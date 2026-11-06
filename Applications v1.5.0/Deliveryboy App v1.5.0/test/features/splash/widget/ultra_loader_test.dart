import 'dart:math';

import 'package:deliveryboy/features/splash/widget/ultra_loader.dart';
import 'package:deliveryboy/features/splash/widget/ultra_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// The loader runs a `repeat()`ing controller, so every test here pumps
/// bounded durations (never `pumpAndSettle`, which would spin forever) and
/// unmounts the widget before finishing so the ticker is disposed.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpLoader(WidgetTester tester, {double? size}) async {
    await tester.pumpWidget(
      pumpTestWidget(size == null ? const UltraLoader() : UltraLoader(size: size)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('paints through UltraPainter at the default 55px', (tester) async {
    printTestDivider('UltraLoader paints through UltraPainter at 55px');
    await pumpLoader(tester);

    final box = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(UltraLoader),
        matching: find.byType(SizedBox),
      ).first,
    );
    printTestLog('width → expected: 55.0, actual: ${box.width}');
    expect(box.width, 55.0);
    printTestLog('height → expected: 55.0, actual: ${box.height}');
    expect(box.height, 55.0);

    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(UltraLoader),
            matching: find.byType(CustomPaint),
          ).first,
        )
        .painter;
    printTestLog('painter → expected: UltraPainter, actual: ${painter.runtimeType}');
    expect(painter, isA<UltraPainter>());
  });

  testWidgets('honours a custom size', (tester) async {
    printTestDivider('UltraLoader honours a custom size');
    await pumpLoader(tester, size: 90);

    final box = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(UltraLoader),
        matching: find.byType(SizedBox),
      ).first,
    );
    printTestLog('width → expected: 90.0, actual: ${box.width}');
    expect(box.width, 90.0);
  });

  testWidgets('takes its color from the onPrimary role', (tester) async {
    printTestDivider('UltraLoader takes its color from the onPrimary role');
    await pumpLoader(tester);

    final context = tester.element(find.byType(UltraLoader));
    final expected = Theme.of(context).colorScheme.onPrimary;
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(UltraLoader),
                    matching: find.byType(CustomPaint),
                  ).first,
                )
                .painter
            as UltraPainter;

    printTestLog('color → expected: $expected, actual: ${painter.color}');
    expect(painter.color, expected);
  });

  testWidgets('keeps rotating frame after frame', (tester) async {
    printTestDivider('UltraLoader keeps rotating frame after frame');
    await pumpLoader(tester);

    Matrix4 currentTransform() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(UltraLoader),
            matching: find.byType(Transform),
          ),
        )
        .transform;

    final first = currentTransform();
    await tester.pump(const Duration(milliseconds: 120));
    final second = currentTransform();
    await tester.pump(const Duration(milliseconds: 120));
    final third = currentTransform();

    printTestLog('frame 1 vs 2 → expected: different, actual: ${first != second}');
    expect(first, isNot(second));
    printTestLog('frame 2 vs 3 → expected: different, actual: ${second != third}');
    expect(second, isNot(third));
  });

  testWidgets('wraps back around instead of stopping after one turn', (
    tester,
  ) async {
    printTestDivider('UltraLoader wraps back around after one turn');
    await pumpLoader(tester);

    // Read the rotation back out of the matrix rather than comparing whole
    // Matrix4s — a full cycle lands on the same angle to ~1e-16, which is not
    // `==` on the raw matrix.
    double currentAngle() {
      final m = tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(UltraLoader),
              matching: find.byType(Transform),
            ),
          )
          .transform;
      return atan2(m.storage[1], m.storage[0]);
    }

    final start = currentAngle();
    // One full 500ms cycle later the controller is back where it started, so
    // this also proves the animation did not simply run to its end and stop.
    await tester.pump(const Duration(milliseconds: 500));
    printTestLog(
      'after one cycle → expected: $start, actual: ${currentAngle()}',
    );
    expect(currentAngle(), closeTo(start, 1e-6));

    await tester.pump(const Duration(milliseconds: 250));
    printTestLog('mid next cycle → expected: moved, actual: ${currentAngle()}');
    expect((currentAngle() - start).abs(), greaterThan(1e-3));
  });

  testWidgets('disposing the loader stops its ticker', (tester) async {
    printTestDivider('UltraLoader disposing stops its ticker');
    await tester.pumpWidget(pumpTestWidget(const UltraLoader()));
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    // A leaked AnimationController fails the test on its own via the ticker
    // debug assert; reaching here with the loader gone is the assertion.
    printTestLog(
      'loader → expected: 0, actual: ${find.byType(UltraLoader).evaluate().length}',
    );
    expect(find.byType(UltraLoader), findsNothing);
  });
}
