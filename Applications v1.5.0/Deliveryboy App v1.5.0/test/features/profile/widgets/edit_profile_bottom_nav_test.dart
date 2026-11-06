import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// Two buttons whose labels, enabled state, and callbacks all depend on which
/// step of the edit-profile flow is showing.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<int> pumpNav(
    WidgetTester tester, {
    required int currentStep,
    bool isLoading = false,
    void Function(String action)? onAction,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        EditProfileBottomNav(
          currentStep: currentStep,
          isLoading: isLoading,
          onBack: () => onAction?.call('back'),
          onNext: () => onAction?.call('next'),
          onSubmit: () => onAction?.call('submit'),
        ),
      ),
    );
    return tester.widgetList<AppButton>(find.byType(AppButton)).length;
  }

  List<String?> labelsOf(WidgetTester tester) => tester
      .widgetList<AppButton>(find.byType(AppButton))
      .map((b) => b.label)
      .toList();

  testWidgets('step 1 offers cancel and next', (tester) async {
    printTestDivider('EditProfileBottomNav shows cancel/next on step 1');
    final count = await pumpNav(tester, currentStep: 0);

    printTestLog('buttons → expected: 2, actual: $count');
    expect(count, 2);
    printTestLog(
      'labels → expected: [${LanguageLabelKeys.cancel}, ${LanguageLabelKeys.next}], '
      'actual: ${labelsOf(tester)}',
    );
    expect(labelsOf(tester), [
      LanguageLabelKeys.cancel,
      LanguageLabelKeys.next,
    ]);
  });

  testWidgets('step 2 offers back and update profile', (tester) async {
    printTestDivider('EditProfileBottomNav shows back/update on step 2');
    await pumpNav(tester, currentStep: 1);

    printTestLog(
      'labels → expected: [${LanguageLabelKeys.back}, ${LanguageLabelKeys.updateProfile}], '
      'actual: ${labelsOf(tester)}',
    );
    expect(labelsOf(tester), [
      LanguageLabelKeys.back,
      LanguageLabelKeys.updateProfile,
    ]);
  });

  testWidgets('the step 1 buttons fire onBack and onNext', (tester) async {
    printTestDivider('EditProfileBottomNav step 1 callbacks');
    final fired = <String>[];
    await pumpNav(tester, currentStep: 0, onAction: fired.add);

    await tester.tap(find.text(LanguageLabelKeys.cancel));
    await tester.pump();
    await tester.tap(find.text(LanguageLabelKeys.next));
    await tester.pump();

    printTestLog('fired → expected: [back, next], actual: $fired');
    expect(fired, ['back', 'next']);
  });

  testWidgets('the step 2 buttons fire onBack and onSubmit', (tester) async {
    printTestDivider('EditProfileBottomNav step 2 callbacks');
    final fired = <String>[];
    await pumpNav(tester, currentStep: 1, onAction: fired.add);

    await tester.tap(find.text(LanguageLabelKeys.back));
    await tester.pump();
    await tester.tap(find.text(LanguageLabelKeys.updateProfile));
    await tester.pump();

    printTestLog('fired → expected: [back, submit], actual: $fired');
    expect(fired, ['back', 'submit']);
  });

  testWidgets('while submitting, the submit button spins and back is disabled', (
    tester,
  ) async {
    printTestDivider('EditProfileBottomNav disables back while submitting');
    final fired = <String>[];
    await pumpNav(
      tester,
      currentStep: 1,
      isLoading: true,
      onAction: fired.add,
    );

    final buttons = tester.widgetList<AppButton>(find.byType(AppButton)).toList();
    printTestLog(
      'back onPressed → expected: null, actual: ${buttons.first.onPressed}',
    );
    expect(buttons.first.onPressed, isNull);
    printTestLog(
      'submit isLoading → expected: true, actual: ${buttons.last.isLoading}',
    );
    expect(buttons.last.isLoading, isTrue);

    await tester.tap(find.byType(AppButton).first, warnIfMissed: false);
    await tester.pump();
    printTestLog('fired → expected: [], actual: $fired');
    expect(fired, isEmpty);
  });
}
