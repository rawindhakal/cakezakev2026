import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/widgets/chat_date_divider.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  setUp(() async {
    // AppDateFormatter reads the country settings' date format from Hive.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpDivider(WidgetTester tester, DateTime date) async {
    await tester.pumpWidget(pumpTestWidget(ChatDateDivider(date: date)));
    await tester.pump();
  }

  testWidgets('today is labelled with the "today" key', (tester) async {
    printTestDivider('ChatDateDivider today is labelled with the "today" key');
    await pumpDivider(tester, DateTime.now());

    // Translations aren't loaded under `flutter test`, so translate() returns
    // the raw key.
    printTestLog('label → expected: "${LanguageLabelKeys.today}" visible');
    expect(find.text(LanguageLabelKeys.today), findsOneWidget);
  });

  testWidgets('a late-evening timestamp today still reads as today', (tester) async {
    printTestDivider('ChatDateDivider a late-evening timestamp today still reads as today');
    final now = DateTime.now();
    await pumpDivider(tester, DateTime(now.year, now.month, now.day, 23, 59));

    printTestLog('label → expected: "${LanguageLabelKeys.today}" visible');
    expect(find.text(LanguageLabelKeys.today), findsOneWidget);
  });

  testWidgets('yesterday is labelled with the "yesterday" key', (tester) async {
    printTestDivider('ChatDateDivider yesterday is labelled with the "yesterday" key');
    await pumpDivider(
      tester,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    printTestLog('label → expected: "${LanguageLabelKeys.yesterday}" visible');
    expect(find.text(LanguageLabelKeys.yesterday), findsOneWidget);
  });

  testWidgets('anything older falls back to the formatted date', (tester) async {
    printTestDivider('ChatDateDivider anything older falls back to the formatted date');
    final old = DateTime(2026, 1, 15, 10, 30);
    await pumpDivider(tester, old);

    final expected = AppDateFormatter.formatDateTime(old);
    printTestLog('label → expected: "$expected" visible');
    expect(find.text(expected), findsOneWidget);
    printTestLog('not "today" → expected: absent');
    expect(find.text(LanguageLabelKeys.today), findsNothing);
  });

  testWidgets('the label sits between two dividers', (tester) async {
    printTestDivider('ChatDateDivider the label sits between two dividers');
    await pumpDivider(tester, DateTime.now());

    printTestLog(
      'dividers → expected: 2, actual: ${find.byType(Divider).evaluate().length}',
    );
    expect(find.byType(Divider), findsNWidgets(2));
  });
}
