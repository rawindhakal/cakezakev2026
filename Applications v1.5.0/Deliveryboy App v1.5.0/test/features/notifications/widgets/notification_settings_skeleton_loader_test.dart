import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/shimmer_builder.dart';
import 'package:deliveryboy/features/notifications/widgets/notification_settings_skeleton_loader.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the default 6 tiles, each with a label + switch box', (
    tester,
  ) async {
    printTestDivider(
      'renders the default 6 tiles, each with a label + switch box',
    );
    await tester.pumpWidget(
      pumpTestWidget(const NotificationSettingsSkeletonLoader()),
    );
    // ShimmerBuilder loops (AnimationController.repeat) — a single bounded
    // pump renders it without waiting on the animation to settle.
    await tester.pump();

    printTestLog(
      'shimmer wrapper → expected: 1, actual: ${find.byType(ShimmerBuilder).evaluate().length}',
    );
    expect(find.byType(ShimmerBuilder), findsOneWidget);
    printTestLog(
      'ListView physics → expected: NeverScrollableScrollPhysics, actual: ${(tester.widget<ListView>(find.byType(ListView)).physics).runtimeType}',
    );
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    // 2 ShimmerBoxes per tile (label + switch pill) x 6 default tiles = 12.
    printTestLog(
      'shimmer boxes → expected: 12, actual: ${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(12));

    final error = tester.takeException();
    printTestLog('render exception → expected: none, actual: $error');
    expect(error, isNull);
  });

  testWidgets('respects a custom itemCount', (tester) async {
    printTestDivider('respects a custom itemCount');
    await tester.pumpWidget(
      pumpTestWidget(const NotificationSettingsSkeletonLoader(itemCount: 3)),
    );
    await tester.pump();

    printTestLog(
      'shimmer boxes → expected: 6 (3 tiles x 2), actual: ${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(6));
  });
}
