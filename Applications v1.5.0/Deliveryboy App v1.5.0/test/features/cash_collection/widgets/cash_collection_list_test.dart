import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_footer.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_card.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_list.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late List<CashCollectionModel> entries;

  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    final response =
        jsonDecode(
              File(
                'test/fixtures/cash_collection/cash_collections_list.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    entries = (response['data']['transactions'] as List)
        .map(
          (e) => CashCollectionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpList(
    WidgetTester tester, {
    List<CashCollectionModel>? collections,
    bool isLoadingMore = false,
    bool hasMore = true,
    Future<void> Function()? onRefresh,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        CashCollectionList(
          collections: collections ?? entries,
          isLoadingMore: isLoadingMore,
          hasMore: hasMore,
          scrollController: ScrollController(),
          onRefresh: onRefresh ?? () async {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when there are no collections', (
    tester,
  ) async {
    printTestDivider('shows the empty state when there are no collections');
    await pumpList(tester, collections: []);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(CashCollectionCard).evaluate().length}',
    );
    expect(find.byType(CashCollectionCard), findsNothing);
  });

  testWidgets('renders one card per collection entry', (tester) async {
    printTestDivider('renders one card per collection entry');
    await pumpList(tester);

    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(CashCollectionCard).evaluate().length}',
    );
    expect(find.byType(CashCollectionCard), findsNWidgets(entries.length));
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
