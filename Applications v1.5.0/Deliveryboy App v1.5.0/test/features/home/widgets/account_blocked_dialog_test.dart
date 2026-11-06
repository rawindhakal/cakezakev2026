import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/widgets/account_blocked_dialog.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> openDialog(WidgetTester tester, {String? remark}) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAccountBlockedDialog(context, remark: remark),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the blocked title and message', (tester) async {
    printTestDivider('shows the blocked title and message');
    await openDialog(tester);

    // Translations aren't loaded in tests, so LocalizationService falls back
    // to the raw key — the key is what renders.
    printTestLog('title → expected: "${LanguageLabelKeys.accountBlocked}" visible');
    expect(find.text(LanguageLabelKeys.accountBlocked), findsOneWidget);
    printTestLog('message → expected: "${LanguageLabelKeys.accountBlockedMessage}" visible');
    expect(find.text(LanguageLabelKeys.accountBlockedMessage), findsOneWidget);
  });

  testWidgets('renders the admin remark when one is given', (tester) async {
    printTestDivider('renders the admin remark when one is given');
    await openDialog(tester, remark: 'Documents expired');

    printTestLog('remark → expected: "Documents expired" visible');
    expect(find.text('Documents expired'), findsOneWidget);
  });

  testWidgets('renders no remark block when the remark is null or empty', (
    tester,
  ) async {
    printTestDivider('renders no remark block when the remark is null or empty');
    await openDialog(tester, remark: '');

    final dialog = tester.widget<AppConfirmDialog>(
      find.byType(AppConfirmDialog),
    );
    printTestLog('extraContent → expected: null, actual: ${dialog.extraContent}');
    expect(dialog.extraContent, isNull);
  });

  testWidgets('cannot be dismissed by a back gesture', (tester) async {
    printTestDivider('cannot be dismissed by a back gesture');
    await openDialog(tester);

    // A blocked rider must not be able to dismiss their way back into the app,
    // so the dialog is wrapped in PopScope(canPop: false) and is not barrier
    // dismissible.
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    printTestLog('PopScope.canPop → expected: false, actual: ${popScope.canPop}');
    expect(popScope.canPop, isFalse);

    // Tapping outside the dialog leaves it in place too.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog(
      'dialog → expected: still open, actual: ${find.byType(AppConfirmDialog).evaluate().length} on screen',
    );
    expect(find.byType(AppConfirmDialog), findsOneWidget);
  });

  // The confirm button logs out through a real AuthRepository/ApiClient and
  // then navigates to the login route — that path is exercised end to end in
  // the home feature's integration test, not here.
}
