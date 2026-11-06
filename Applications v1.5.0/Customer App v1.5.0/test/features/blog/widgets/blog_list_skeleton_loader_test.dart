import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/features/blog/widgets/blog_list_skeleton_loader.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the default 4 placeholder cards without crashing', (
    tester,
  ) async {
    printTestDivider('renders the default 4 placeholder cards without crashing');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 2000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(pumpTestWidget(const BlogListSkeletonLoader()));

    // Each card has 8 ShimmerBoxes: image + category chip + date + 2 title
    // lines + 2 description lines + 2 meta boxes = 9 actually per the
    // widget's own _card layout: 1 image + 1 chip + 1 date + 2 title + 2
    // description + 2 meta = 9.
    printTestLog(
      'shimmer boxes → expected: 36 (4 cards × 9), actual: '
      '${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(36));
  });

  testWidgets('renders a custom item count, same shape per card', (tester) async {
    printTestDivider('renders a custom item count, same shape per card');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 2000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(const BlogListSkeletonLoader(itemCount: 2)),
    );

    printTestLog(
      'shimmer boxes → expected: 18 (2 cards × 9), actual: '
      '${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(18));
  });
}
