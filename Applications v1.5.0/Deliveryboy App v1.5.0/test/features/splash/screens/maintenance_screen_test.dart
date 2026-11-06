import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/splash/screens/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// Translations aren't loaded under `flutter test`, so `context.translate`
/// echoes the raw key back — assertions here match `LanguageLabelKeys.*`
/// rather than English copy (see the auth-suite gotcha).
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(WidgetTester tester, {String? remark}) async {
    await tester.pumpWidget(
      // MaintenanceScreen builds its own AppScaffold.
      pumpTestWidget(MaintenanceScreen(remark: remark), wrapInScaffold: false),
    );
    await tester.pump();
  }

  testWidgets('shows the maintenance illustration and title', (tester) async {
    printTestDivider('MaintenanceScreen shows the illustration and title');
    await pumpScreen(tester);

    final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
    printTestLog(
      'icon → expected: ${AssetsConstants.noMaintenanceFound}, actual: ${icon.path}',
    );
    expect(icon.path, AssetsConstants.noMaintenanceFound);
    printTestLog('title → expected: "${LanguageLabelKeys.maintenanceTitle}" visible');
    expect(find.text(LanguageLabelKeys.maintenanceTitle), findsOneWidget);
  });

  testWidgets('falls back to the generic subtitle when there is no remark', (
    tester,
  ) async {
    printTestDivider('MaintenanceScreen falls back to the generic subtitle');
    await pumpScreen(tester);

    printTestLog(
      'message → expected: "${LanguageLabelKeys.maintenanceSubtitle}" visible',
    );
    expect(find.text(LanguageLabelKeys.maintenanceSubtitle), findsOneWidget);
  });

  testWidgets('an empty remark falls back the same way a null one does', (
    tester,
  ) async {
    printTestDivider('MaintenanceScreen an empty remark falls back too');
    await pumpScreen(tester, remark: '');

    printTestLog(
      'message → expected: "${LanguageLabelKeys.maintenanceSubtitle}" visible',
    );
    expect(find.text(LanguageLabelKeys.maintenanceSubtitle), findsOneWidget);
  });

  testWidgets('shows the server remark when there is one', (tester) async {
    printTestDivider('MaintenanceScreen shows the server remark');
    await pumpScreen(tester, remark: 'Back at 6pm IST');

    printTestLog('message → expected: "Back at 6pm IST" visible');
    expect(find.text('Back at 6pm IST'), findsOneWidget);
    printTestLog(
      'fallback → expected: absent, actual: '
      '${find.text(LanguageLabelKeys.maintenanceSubtitle).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.maintenanceSubtitle), findsNothing);
  });

  testWidgets('a whitespace-only remark is still treated as a remark', (
    tester,
  ) async {
    printTestDivider('MaintenanceScreen a whitespace-only remark is used as-is');
    await pumpScreen(tester, remark: '   ');

    // Documented, not asserted as desirable: the check is `isNotEmpty`, not a
    // trimmed one (unlike `hasSalaryDetail`/`hasWalletTransactionDetail`), so
    // a blank-but-present remark renders as an empty message line.
    printTestLog(
      'fallback → expected: absent, actual: '
      '${find.text(LanguageLabelKeys.maintenanceSubtitle).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.maintenanceSubtitle), findsNothing);
  });

  testWidgets('cannot be popped — maintenance blocks the whole app', (
    tester,
  ) async {
    printTestDivider('MaintenanceScreen cannot be popped');
    await pumpScreen(tester);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    printTestLog('canPop → expected: false, actual: ${popScope.canPop}');
    expect(popScope.canPop, isFalse);
  });
}
