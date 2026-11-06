import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';
import 'package:deliveryboy/features/home/widgets/toggle_status_dialog.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockDeliveryBoyStatusCubit statusCubit;

  setUp(() {
    statusCubit = MockDeliveryBoyStatusCubit();
    whenListen(
      statusCubit,
      const Stream<DeliveryBoyStatusState>.empty(),
      initialState: const DeliveryBoyStatusLoaded((status: 1, remark: null)),
    );
    when(() => statusCubit.toggleOnline()).thenAnswer((_) async {});
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> openDialog(
    WidgetTester tester, {
    required bool goingOnline,
  }) async {
    await tester.pumpWidget(
      BlocProvider<DeliveryBoyStatusCubit>.value(
        value: statusCubit,
        // Providers sit above MaterialApp: the dialog is a sibling route on
        // the same Navigator and wouldn't inherit them from `home:` alone.
        child: pumpTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showToggleStatusDialog(context, goingOnline: goingOnline),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('going online shows the go-online copy', (tester) async {
    printTestDivider('going online shows the go-online copy');
    await openDialog(tester, goingOnline: true);

    // Translations aren't loaded in tests, so LocalizationService falls back
    // to the raw key — the key is what renders.
    printTestLog('message → expected: "${LanguageLabelKeys.confirmGoOnline}" visible');
    expect(find.text(LanguageLabelKeys.confirmGoOnline), findsOneWidget);
    printTestLog('confirm label → expected: "${LanguageLabelKeys.goOnline}" visible');
    expect(find.text(LanguageLabelKeys.goOnline), findsOneWidget);
  });

  testWidgets('going offline shows the go-offline copy', (tester) async {
    printTestDivider('going offline shows the go-offline copy');
    await openDialog(tester, goingOnline: false);

    printTestLog('message → expected: "${LanguageLabelKeys.confirmGoOffline}" visible');
    expect(find.text(LanguageLabelKeys.confirmGoOffline), findsOneWidget);
    printTestLog('confirm label → expected: "${LanguageLabelKeys.goOffline}" visible');
    expect(find.text(LanguageLabelKeys.goOffline), findsOneWidget);
  });

  testWidgets('confirming closes the dialog and toggles the status', (
    tester,
  ) async {
    printTestDivider('confirming closes the dialog and toggles the status');
    await openDialog(tester, goingOnline: true);

    await tester.tap(find.text(LanguageLabelKeys.goOnline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => statusCubit.toggleOnline()).called(1);
    printTestLog(
      'dialog → expected: closed, actual: ${find.byType(AppConfirmDialog).evaluate().length} on screen',
    );
    expect(find.byType(AppConfirmDialog), findsNothing);
  });

  testWidgets('cancelling closes the dialog without toggling', (tester) async {
    printTestDivider('cancelling closes the dialog without toggling');
    await openDialog(tester, goingOnline: true);

    await tester.tap(find.text(LanguageLabelKeys.cancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verifyNever(() => statusCubit.toggleOnline());
    printTestLog(
      'dialog → expected: closed, actual: ${find.byType(AppConfirmDialog).evaluate().length} on screen',
    );
    expect(find.byType(AppConfirmDialog), findsNothing);
  });
}
