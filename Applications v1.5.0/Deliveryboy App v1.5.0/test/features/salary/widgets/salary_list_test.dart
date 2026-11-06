import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_footer.dart';
import 'package:deliveryboy/features/salary/models/salary_model.dart';
import 'package:deliveryboy/features/salary/widgets/salary_card.dart';
import 'package:deliveryboy/features/salary/widgets/salary_list.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late List<SalaryModel> entries;

  setUp(() {
    entries = List.generate(
      3,
      (i) => SalaryModel.fromJson({
        'id': i + 1,
        'amount': (i + 1) * 1000.0,
        'currency': '₹',
      }),
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpList(
    WidgetTester tester, {
    List<SalaryModel>? salaries,
    bool isLoadingMore = false,
    bool hasMore = true,
    Future<void> Function()? onRefresh,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        SalaryList(
          salaries: salaries ?? entries,
          total: (salaries ?? entries).length,
          isLoadingMore: isLoadingMore,
          hasMore: hasMore,
          scrollController: ScrollController(),
          onRefresh: onRefresh ?? () async {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when there are no salary entries', (
    tester,
  ) async {
    printTestDivider('shows the empty state when there are no salary entries');
    await pumpList(tester, salaries: []);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(SalaryCard).evaluate().length}',
    );
    expect(find.byType(SalaryCard), findsNothing);
  });

  testWidgets('renders one card per salary entry', (tester) async {
    printTestDivider('renders one card per salary entry');
    await pumpList(tester);

    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(SalaryCard).evaluate().length}',
    );
    expect(find.byType(SalaryCard), findsNWidgets(entries.length));
  });

  testWidgets('shows the loading-more footer while isLoadingMore is true', (
    tester,
  ) async {
    printTestDivider('shows the loading-more footer while isLoadingMore is true');
    await pumpList(tester, isLoadingMore: true);

    printTestLog(
      'footer → expected: 1, actual: ${find.byType(PaginatedListFooter).evaluate().length}',
    );
    expect(find.byType(PaginatedListFooter), findsOneWidget);
  });

  testWidgets('calls onRefresh when the list is pulled to refresh', (
    tester,
  ) async {
    printTestDivider('calls onRefresh when the list is pulled to refresh');
    var refreshed = false;
    await pumpList(
      tester,
      onRefresh: () async {
        refreshed = true;
      },
    );

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();

    printTestLog('onRefresh called → expected: true, actual: $refreshed');
    expect(refreshed, isTrue);
  });
}
