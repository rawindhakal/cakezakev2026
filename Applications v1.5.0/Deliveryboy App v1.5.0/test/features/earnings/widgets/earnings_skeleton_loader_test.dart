import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_skeleton_loader.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the summary card placeholder plus two rows of stat tiles', (
    tester,
  ) async {
    printTestDivider(
      'renders the summary card placeholder plus two rows of stat tiles',
    );
    await tester.pumpWidget(pumpTestWidget(const EarningsSkeletonLoader()));

    printTestLog(
      'shimmer wrapper → expected: 1, actual: ${find.byType(ShimmerLoading).evaluate().length}',
    );
    expect(find.byType(ShimmerLoading), findsOneWidget);
    // 1 summary-card box + 2 rows x 2 tiles each = 5 ShimmerBoxes total
    // (ShimmerCardRow itself renders 2 ShimmerBoxes).
    printTestLog(
      'shimmer card rows → expected: 2, actual: ${find.byType(ShimmerCardRow).evaluate().length}',
    );
    expect(find.byType(ShimmerCardRow), findsNWidgets(2));
    printTestLog(
      'shimmer boxes → expected: 5, actual: ${find.byType(ShimmerBox).evaluate().length}',
    );
    expect(find.byType(ShimmerBox), findsNWidgets(5));

    final error = tester.takeException();
    printTestLog('render exception → expected: none, actual: $error');
    expect(error, isNull);
  });
}
