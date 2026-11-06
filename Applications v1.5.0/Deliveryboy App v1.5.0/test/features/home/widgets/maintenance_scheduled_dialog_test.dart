import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/widgets/maintenance_scheduled_dialog.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  // maybeShow reads cached settings and the dismissed-window marker out of
  // SettingsHiveBox, and "OK" writes the marker back.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    // The "once per session" flag is static, so it leaks between tests unless
    // it is reset the way logout does.
    MaintenanceScheduledDialog.resetSession();
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  /// Formats a UTC instant the way the API sends it: a wall-clock string with
  /// no timezone marker, which the dialog reinterprets as UTC.
  String apiTime(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')}';

  AppSettingsData settings({
    String appMode = '0',
    String? start,
    String? end,
  }) => AppSettingsData.fromJson({
    'app_mode_delivery_boy': appMode,
    'app_mode_delivery_boy_start': ?start,
    'app_mode_delivery_boy_end': ?end,
  });

  /// Tears the tree down so an open dialog is disposed. Without this a test
  /// that ends with the dialog still mounted leaves its 1-second periodic
  /// ticker running, which stalls the runner.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// Pumps a host screen and calls `maybeShow` from it, returning whether the
  /// dialog was shown.
  Future<bool> callMaybeShow(
    WidgetTester tester,
    AppSettingsData? data,
  ) async {
    var shown = false;
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                shown = MaintenanceScheduledDialog.maybeShow(
                  context,
                  settings: data,
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return shown;
  }

  group('maybeShow', () {
    testWidgets('shows the dialog for an upcoming window', (tester) async {
      printTestDivider('shows the dialog for an upcoming window');
      final now = DateTime.now().toUtc();
      final shown = await callMaybeShow(
        tester,
        settings(
          start: apiTime(now.add(const Duration(hours: 2))),
          end: apiTime(now.add(const Duration(hours: 4))),
        ),
      );

      printTestLog('returned → expected: true, actual: $shown');
      expect(shown, isTrue);
      printTestLog(
        'dialog → expected: 1, actual: ${find.byType(MaintenanceScheduledDialog).evaluate().length}',
      );
      expect(find.byType(MaintenanceScheduledDialog), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the dialog for a window already in progress', (
      tester,
    ) async {
      printTestDivider('shows the dialog for a window already in progress');
      final now = DateTime.now().toUtc();
      final shown = await callMaybeShow(
        tester,
        settings(
          start: apiTime(now.subtract(const Duration(hours: 1))),
          end: apiTime(now.add(const Duration(hours: 1))),
        ),
      );

      printTestLog('returned → expected: true, actual: $shown');
      expect(shown, isTrue);
      await unmount(tester);
    });

    testWidgets('stays quiet for a window that has already elapsed', (
      tester,
    ) async {
      printTestDivider('stays quiet for a window that has already elapsed');
      final now = DateTime.now().toUtc();
      final shown = await callMaybeShow(
        tester,
        settings(
          start: apiTime(now.subtract(const Duration(hours: 4))),
          end: apiTime(now.subtract(const Duration(hours: 2))),
        ),
      );

      printTestLog('returned → expected: false, actual: $shown');
      expect(shown, isFalse);
      expect(find.byType(MaintenanceScheduledDialog), findsNothing);
    });

    testWidgets('stays quiet when full maintenance mode is already on', (
      tester,
    ) async {
      printTestDivider('stays quiet when full maintenance mode is already on');
      // app_mode == '1' is handled by the full-screen maintenance route, so
      // the scheduled-window dialog must not double up on it.
      final now = DateTime.now().toUtc();
      final shown = await callMaybeShow(
        tester,
        settings(
          appMode: '1',
          start: apiTime(now.add(const Duration(hours: 2))),
          end: apiTime(now.add(const Duration(hours: 4))),
        ),
      );

      printTestLog('returned → expected: false, actual: $shown');
      expect(shown, isFalse);
    });

    testWidgets('stays quiet when there is no start time', (tester) async {
      printTestDivider('stays quiet when there is no start time');
      final shown = await callMaybeShow(tester, settings());

      printTestLog('returned → expected: false, actual: $shown');
      expect(shown, isFalse);
    });

    testWidgets('stays quiet when there are no settings at all', (tester) async {
      printTestDivider('stays quiet when there are no settings at all');
      final shown = await callMaybeShow(tester, null);

      printTestLog('returned → expected: false, actual: $shown');
      expect(shown, isFalse);
    });

    testWidgets('shows an open-ended window that has no end time', (
      tester,
    ) async {
      printTestDivider('shows an open-ended window that has no end time');
      final now = DateTime.now().toUtc();
      final shown = await callMaybeShow(
        tester,
        settings(start: apiTime(now.add(const Duration(hours: 2)))),
      );

      printTestLog('returned → expected: true, actual: $shown');
      expect(shown, isTrue);
      await unmount(tester);
    });

    testWidgets('shows the dialog only once per app session', (tester) async {
      printTestDivider('shows the dialog only once per app session');
      final now = DateTime.now().toUtc();
      final data = settings(
        start: apiTime(now.add(const Duration(hours: 2))),
        end: apiTime(now.add(const Duration(hours: 4))),
      );

      final first = await callMaybeShow(tester, data);
      printTestLog('first call → expected: true, actual: $first');
      expect(first, isTrue);

      // Unmount before asking again: the open dialog covers the host button,
      // so a second tap would miss it rather than exercising the guard.
      await unmount(tester);
      final second = await callMaybeShow(tester, data);
      printTestLog('second call → expected: false, actual: $second');
      expect(second, isFalse);
    });

    testWidgets('stays quiet for a window the rider already dismissed', (
      tester,
    ) async {
      printTestDivider('stays quiet for a window the rider already dismissed');
      final now = DateTime.now().toUtc();
      final start = apiTime(now.add(const Duration(hours: 2)));
      final end = apiTime(now.add(const Duration(hours: 4)));
      // Wrapped in runAsync: a Hive write is real file I/O, and awaiting it
      // straight from a testWidgets body hangs the runner — the test zone only
      // pumps its own fake clock, never the event loop the write completes on.
      await tester.runAsync(
        () => SettingsHiveBox.instance.setMaintenanceDialogDismissedWindow(
          '${start}_$end',
        ),
      );

      final shown = await callMaybeShow(tester, settings(start: start, end: end));

      printTestLog('returned → expected: false, actual: $shown');
      expect(shown, isFalse);
    });

    testWidgets('shows a different window even after one was dismissed', (
      tester,
    ) async {
      printTestDivider('shows a different window even after one was dismissed');
      final now = DateTime.now().toUtc();
      await tester.runAsync(
        () => SettingsHiveBox.instance.setMaintenanceDialogDismissedWindow(
          'some_old_window',
        ),
      );

      final shown = await callMaybeShow(
        tester,
        settings(
          start: apiTime(now.add(const Duration(hours: 2))),
          end: apiTime(now.add(const Duration(hours: 4))),
        ),
      );

      printTestLog('returned → expected: true, actual: $shown');
      expect(shown, isTrue);
      await unmount(tester);
    });
  });

  group('the dialog itself', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      required DateTime startLocal,
      DateTime? endLocal,
      String dismissKey = 'window-1',
    }) async {
      await tester.pumpWidget(
        pumpTestWidget(
          MaintenanceScheduledDialog(
            startLocal: startLocal,
            endLocal: endLocal,
            dismissKey: dismissKey,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the title and an OK button', (tester) async {
      printTestDivider('renders the title and an OK button');
      final now = DateTime.now();
      await pumpDialog(
        tester,
        startLocal: now.add(const Duration(hours: 2)),
        endLocal: now.add(const Duration(hours: 4)),
      );

      // Translations aren't loaded in tests, so copy falls back to raw keys.
      printTestLog('title → expected: "${LanguageLabelKeys.scheduledMaintenanceTitle}" visible');
      expect(
        find.text(LanguageLabelKeys.scheduledMaintenanceTitle),
        findsOneWidget,
      );
      printTestLog('OK button → expected: 1, actual: ${find.byType(AppButton).evaluate().length}');
      expect(find.byType(AppButton), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('describes a multi-hour window in hours', (tester) async {
      printTestDivider('describes a multi-hour window in hours');
      final now = DateTime.now();
      await pumpDialog(
        tester,
        startLocal: now.add(const Duration(hours: 2)),
        endLocal: now.add(const Duration(hours: 5)),
      );

      printTestLog('duration → expected: text containing "3 hours"');
      expect(find.textContaining('3 hours'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('describes a multi-day window in days', (tester) async {
      printTestDivider('describes a multi-day window in days');
      final now = DateTime.now();
      await pumpDialog(
        tester,
        startLocal: now.add(const Duration(hours: 1)),
        endLocal: now.add(const Duration(days: 2, hours: 1)),
      );

      printTestLog('duration → expected: text containing "2 days"');
      expect(find.textContaining('2 days'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('describes a sub-hour window in minutes, singular for one', (
      tester,
    ) async {
      printTestDivider('describes a sub-hour window in minutes, singular for one');
      final now = DateTime.now();
      await pumpDialog(
        tester,
        startLocal: now.add(const Duration(hours: 1)),
        endLocal: now.add(const Duration(hours: 1, minutes: 1)),
      );

      printTestLog('duration → expected: text containing "1 minute"');
      expect(find.textContaining('1 minute'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('omits the duration for an open-ended window', (tester) async {
      printTestDivider('omits the duration for an open-ended window');
      await pumpDialog(
        tester,
        startLocal: DateTime.now().add(const Duration(hours: 2)),
      );

      printTestLog('duration → expected: no hours/days/minutes text');
      expect(find.textContaining('hours'), findsNothing);
      expect(find.textContaining('minutes'), findsNothing);
    });

    testWidgets('counts down and keeps ticking each second', (tester) async {
      printTestDivider('counts down and keeps ticking each second');
      final now = DateTime.now();
      await pumpDialog(
        tester,
        startLocal: now.subtract(const Duration(minutes: 1)),
        endLocal: now.add(const Duration(minutes: 5)),
      );

      // A window in progress counts down to its end.
      await tester.pump(const Duration(seconds: 1));
      final firstFrame = find.textContaining(':').evaluate().length;
      printTestLog('countdown pill → expected: rendered, actual: $firstFrame match(es)');
      expect(firstFrame, greaterThan(0));

      await tester.pump(const Duration(seconds: 1));
      printTestLog('still ticking → expected: no exception, actual: ${tester.takeException()}');

      // Let the periodic timer stop before the test ends.
      await unmount(tester);
    });

    testWidgets('runs no countdown timer for an open-ended window', (
      tester,
    ) async {
      printTestDivider('runs no countdown timer for an open-ended window');
      // Without an end time there is nothing to count towards, so initState
      // must not start a periodic timer — one left running would fail the
      // test with a pending-timer error.
      await pumpDialog(
        tester,
        startLocal: DateTime.now().add(const Duration(hours: 2)),
      );
      await tester.pump(const Duration(seconds: 2));

      printTestLog('exception → expected: none, actual: ${tester.takeException()}');
      expect(find.byType(MaintenanceScheduledDialog), findsOneWidget);
    });

    // Not covered by a widget test: tapping OK. Its handler fires
    // SettingsHiveBox.setMaintenanceDialogDismissedWindow without awaiting it,
    // and a Hive write started inside a widget test's fake-clock zone never
    // completes — the pending future then blocks tearDown's box.close()
    // forever, hanging the runner with no failure message. The two halves of
    // that handler are covered separately instead: the storage round-trip by
    // the plain tests below, and the dismiss behaviour by
    // "stays quiet for a window the rider already dismissed" above.
  });

  // A plain test, not testWidgets: awaiting real Hive file I/O is safe here,
  // whereas inside a widget test's fake-clock zone it never completes.
  test('the dismissed-window marker round-trips through SettingsHiveBox', () async {
    printTestDivider('the dismissed-window marker round-trips through SettingsHiveBox');
    await SettingsHiveBox.instance.setMaintenanceDialogDismissedWindow(
      'start_end',
    );

    final stored = SettingsHiveBox.instance.maintenanceDialogDismissedWindow;
    printTestLog('stored window → expected: "start_end", actual: "$stored"');
    expect(stored, 'start_end');
  });

  test('the dismissed-window marker defaults to empty', () {
    printTestDivider('the dismissed-window marker defaults to empty');
    final stored = SettingsHiveBox.instance.maintenanceDialogDismissedWindow;
    printTestLog('stored window → expected: "", actual: "$stored"');
    expect(stored, '');
  });
}
