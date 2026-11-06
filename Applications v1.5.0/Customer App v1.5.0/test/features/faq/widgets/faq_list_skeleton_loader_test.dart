import 'package:flutter_test/flutter_test.dart';
import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/features/faq/widgets/faq_list_skeleton_loader.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the default 8 placeholder tiles without crashing', (
    tester,
  ) async {
    printTestDivider('renders the default 8 placeholder tiles without crashing');
    await tester.pumpWidget(pumpTestWidget(const FaqListSkeletonLoader()));

    printTestLog(
      'shimmer boxes → expected: 16 (8 tiles × question + chevron), actual: '
      '${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(16));
  });

  testWidgets('renders a custom item count', (tester) async {
    printTestDivider('renders a custom item count');
    await tester.pumpWidget(
      pumpTestWidget(const FaqListSkeletonLoader(itemCount: 3)),
    );

    printTestLog(
      'shimmer boxes → expected: 6, actual: ${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(6));
  });
}
