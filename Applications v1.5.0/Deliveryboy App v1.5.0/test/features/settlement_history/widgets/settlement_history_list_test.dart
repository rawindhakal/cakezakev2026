import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_footer.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_card.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_list.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late List<SettlementHistoryData> entries;

  setUp(() async {
    // The cards format created_at through AppDateFormatter, which reads the
    // server-provided format out of SettingsHiveBox.
    await HiveTestHelper.setUp(settingsBox);
    final response =
        jsonDecode(
              File(
                'test/fixtures/settlement_history/settlement_history_list.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    entries = SettlementHistoryResponse.fromJson(response).data!;
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpList(
    WidgetTester tester, {
    List<SettlementHistoryData>? transfers,
    bool isLoadingMore = false,
    bool hasMore = true,
    Future<void> Function()? onRefresh,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        TransferList(
          transfers: transfers ?? entries,
          isLoadingMore: isLoadingMore,
          hasMore: hasMore,
          scrollController: ScrollController(),
          onRefresh: onRefresh ?? () async {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when there are no transfers', (
    tester,
  ) async {
    printTestDivider('shows the empty state when there are no transfers');
    await pumpList(tester, transfers: []);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(SettlementHistoryCard).evaluate().length}',
    );
    expect(find.byType(SettlementHistoryCard), findsNothing);
    printTestLog(
      'empty copy → expected: "${LanguageLabelKeys.noSettlementHistory}" visible',
    );
    expect(find.text(LanguageLabelKeys.noSettlementHistory), findsWidgets);
  });

  testWidgets('renders one card per settlement entry', (tester) async {
    printTestDivider('renders one card per settlement entry');
    await pumpList(tester);

    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(SettlementHistoryCard).evaluate().length}',
    );
    expect(find.byType(SettlementHistoryCard), findsNWidgets(entries.length));
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
