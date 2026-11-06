import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_card.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late List<CashCollectionModel> entries;

  // The card formats the transaction date through AppDateFormatter, which
  // reads the server-provided format out of SettingsHiveBox.
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

  CashCollectionModel byId(String id) =>
      entries.firstWhere((e) => e.id == id);

  Future<void> pumpCard(WidgetTester tester, CashCollectionModel item) async {
    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(child: CashCollectionCard(item: item)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the order id and status text', (tester) async {
    printTestDivider('shows the order id and status text');
    await pumpCard(tester, byId('301'));

    printTestLog('order id → expected: "1006" visible');
    expect(find.textContaining('1006'), findsWidgets);
    // status "6" capitalized has no case change on a numeric string, but the
    // widget still renders whatever capitalize() returns for it.
    printTestLog('message → expected: "Cash collected for order #1006" visible');
    expect(find.text('Cash collected for order #1006'), findsOneWidget);
  });

  testWidgets('falls back to the raw id when orderId is missing', (
    tester,
  ) async {
    printTestDivider('falls back to the raw id when orderId is missing');
    final item = byId('301');
    item.orderId = null;
    await pumpCard(tester, item);

    printTestLog('id → expected: "301" visible');
    expect(find.textContaining('301'), findsWidgets);
  });

  testWidgets('shows an em dash when both orderId and id are missing', (
    tester,
  ) async {
    printTestDivider('shows an em dash when both orderId and id are missing');
    final item = byId('301');
    item.orderId = null;
    item.id = null;
    await pumpCard(tester, item);

    printTestLog('placeholder → expected: "—" present in the order-id line');
    expect(find.textContaining('—'), findsWidgets);
  });

  testWidgets('shows a dash placeholder when the message is empty', (
    tester,
  ) async {
    printTestDivider('shows a dash placeholder when the message is empty');
    await pumpCard(tester, byId('302'));

    printTestLog('message placeholder → expected: "—" visible');
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('prefixes the amount with the currency symbol from the item', (
    tester,
  ) async {
    printTestDivider('prefixes the amount with the currency symbol from the item');
    await pumpCard(tester, byId('301'));

    printTestLog('amount → expected: "₹560.00" visible');
    expect(find.text('₹560.00'), findsOneWidget);
  });

  testWidgets('shows 0 amount fallback when amount is null', (tester) async {
    printTestDivider('shows 0 amount fallback when amount is null');
    final item = byId('301');
    item.amount = null;
    item.currency = null;
    await pumpCard(tester, item);

    printTestLog('amount → expected: "0" visible');
    expect(find.text('0'), findsOneWidget);
  });
}
