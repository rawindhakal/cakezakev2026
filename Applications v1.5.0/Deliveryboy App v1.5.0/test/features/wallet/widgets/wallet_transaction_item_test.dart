import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_transaction_item.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  // The card formats the date through AppDateFormatter, which reads the
  // server-provided format out of SettingsHiveBox.
  setUp(() => HiveTestHelper.setUp(settingsBox));
  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpItem(WidgetTester tester, WithdrawRequests item) async {
    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(child: WalletTransactionItem(transaction: item)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the request id and currency-prefixed amount', (
    tester,
  ) async {
    printTestDivider('shows the request id and currency-prefixed amount');
    await pumpItem(
      tester,
      WithdrawRequests.fromJson({
        'id': '501',
        'amount': '1000.00',
        'currency': '₹',
        'status': '0',
      }),
    );

    printTestLog('id → expected: "501" visible in the request-id line');
    expect(find.textContaining('501'), findsWidgets);
    printTestLog('amount → expected: "₹1000.00" visible');
    expect(find.text('₹1000.00'), findsOneWidget);
  });

  testWidgets('falls back to a 0 amount and empty currency prefix when both are null', (
    tester,
  ) async {
    printTestDivider(
      'falls back to a 0 amount and empty currency prefix when both are null',
    );
    await pumpItem(
      tester,
      WithdrawRequests.fromJson({'id': '501', 'status': '0'}),
    );

    printTestLog('amount → expected: "0" visible');
    expect(find.text('0'), findsOneWidget);
  });

  group('status text', () {
    testWidgets('pending', (tester) async {
      printTestDivider('status text pending');
      await pumpItem(
        tester,
        WithdrawRequests.fromJson({'id': '1', 'status': '0'}),
      );
      printTestLog(
        'status text → expected: "${LanguageLabelKeys.pending}" visible',
      );
      expect(find.text(LanguageLabelKeys.pending), findsOneWidget);
    });

    testWidgets('approved', (tester) async {
      printTestDivider('status text approved');
      await pumpItem(
        tester,
        WithdrawRequests.fromJson({'id': '1', 'status': '1'}),
      );
      printTestLog(
        'status text → expected: "${LanguageLabelKeys.approved}" visible',
      );
      expect(find.text(LanguageLabelKeys.approved), findsOneWidget);
    });

    testWidgets('rejected', (tester) async {
      printTestDivider('status text rejected');
      await pumpItem(
        tester,
        WithdrawRequests.fromJson({'id': '1', 'status': '2'}),
      );
      printTestLog(
        'status text → expected: "${LanguageLabelKeys.rejected}" visible',
      );
      expect(find.text(LanguageLabelKeys.rejected), findsOneWidget);
    });

    testWidgets('unknown/unmapped status falls back to statusUnknown', (
      tester,
    ) async {
      printTestDivider('status text unknown/unmapped status falls back to statusUnknown');
      await pumpItem(
        tester,
        WithdrawRequests.fromJson({'id': '1', 'status': '99'}),
      );
      printTestLog(
        'status text → expected: "${LanguageLabelKeys.statusUnknown}" visible',
      );
      expect(find.text(LanguageLabelKeys.statusUnknown), findsOneWidget);
    });
  });

  testWidgets('tapping a row with a message opens the detail sheet', (
    tester,
  ) async {
    printTestDivider('tapping a row with a message opens the detail sheet');
    await pumpItem(
      tester,
      WithdrawRequests.fromJson({
        'id': '501',
        'status': '0',
        'message': 'Need cash for fuel',
      }),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog(
      'detail message → expected: "Need cash for fuel" visible, actual: ${find.text('Need cash for fuel').evaluate().length}',
    );
    expect(find.text('Need cash for fuel'), findsOneWidget);
  });

  testWidgets('a row with neither message nor remark is not tappable', (
    tester,
  ) async {
    printTestDivider('a row with neither message nor remark is not tappable');
    await pumpItem(
      tester,
      WithdrawRequests.fromJson({'id': '501', 'status': '0'}),
    );

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    printTestLog('onTap → expected: null, actual: ${inkWell.onTap}');
    expect(inkWell.onTap, isNull);
  });
}
