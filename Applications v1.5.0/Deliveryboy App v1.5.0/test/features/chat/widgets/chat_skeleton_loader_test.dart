import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/shimmer_builder.dart';
import 'package:deliveryboy/features/chat/widgets/chat_skeleton_loader.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpLoader(WidgetTester tester, {int? itemCount}) async {
    await tester.pumpWidget(
      pumpTestWidget(
        SizedBox(
          height: 900,
          child: itemCount == null
              ? const ChatSkeletonLoader()
              : ChatSkeletonLoader(itemCount: itemCount),
        ),
      ),
    );
    // Bounded pump — the shimmer runs a looping animation, so pumpAndSettle
    // would never return.
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders eight placeholder bubbles by default', (tester) async {
    printTestDivider('ChatSkeletonLoader renders eight placeholder bubbles by default');
    await pumpLoader(tester);

    printTestLog(
      'shimmer boxes → expected: 8, actual: ${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(8));
  });

  testWidgets('honours an explicit item count', (tester) async {
    printTestDivider('ChatSkeletonLoader honours an explicit item count');
    await pumpLoader(tester, itemCount: 3);

    printTestLog(
      'shimmer boxes → expected: 3, actual: ${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(3));
  });

  testWidgets('alternates the placeholder bubbles left and right', (tester) async {
    printTestDivider('ChatSkeletonLoader alternates the placeholder bubbles left and right');
    await pumpLoader(tester, itemCount: 2);

    final alignments = tester
        .widgetList<Align>(
          find.descendant(
            of: find.byType(ChatSkeletonLoader),
            matching: find.byType(Align),
          ),
        )
        .map((a) => a.alignment)
        .toList();
    printTestLog(
      'alignments → expected: [centerLeft, centerRight], actual: $alignments',
    );
    expect(alignments, [Alignment.centerLeft, Alignment.centerRight]);
  });

  testWidgets('the placeholder list cannot be scrolled', (tester) async {
    printTestDivider('ChatSkeletonLoader the placeholder list cannot be scrolled');
    await pumpLoader(tester);

    final listView = tester.widget<ListView>(find.byType(ListView));
    printTestLog(
      'physics → expected: NeverScrollableScrollPhysics, actual: ${listView.physics.runtimeType}',
    );
    expect(listView.physics, isA<NeverScrollableScrollPhysics>());
  });
}
