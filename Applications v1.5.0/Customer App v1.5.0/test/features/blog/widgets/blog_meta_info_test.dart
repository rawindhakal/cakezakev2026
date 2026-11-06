import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/widgets/blog_meta_info.dart';
import 'package:customer/core/localization/language_label_key.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Blog blog({String? readTime, String? viewsCount, String? createdAt}) =>
      Blog.fromJson({
        'id': '1',
        'read_time': readTime,
        'views_count': viewsCount,
        'created_at': createdAt,
      });

  testWidgets('read time and views default to 0 when the model fields are missing', (
    tester,
  ) async {
    printTestDivider(
      'read time and views default to 0 when the model fields are missing',
    );
    await tester.pumpWidget(pumpTestWidget(BlogMetaInfo(blog: blog())));

    final readText = '0 ${LanguageLabelKeys.read}';
    final viewsText = '0 ${LanguageLabelKeys.views}';
    printTestLog('read text → expected: "$readText"');
    expect(find.text(readText), findsOneWidget);
    printTestLog('views text → expected: "$viewsText"');
    expect(find.text(viewsText), findsOneWidget);
  });

  testWidgets('shows the actual read time and views count when present', (
    tester,
  ) async {
    printTestDivider('shows the actual read time and views count when present');
    await tester.pumpWidget(
      pumpTestWidget(BlogMetaInfo(blog: blog(readTime: '5', viewsCount: '42'))),
    );

    printTestLog('read text → expected: "5 ${LanguageLabelKeys.read}"');
    expect(find.text('5 ${LanguageLabelKeys.read}'), findsOneWidget);
    printTestLog('views text → expected: "42 ${LanguageLabelKeys.views}"');
    expect(find.text('42 ${LanguageLabelKeys.views}'), findsOneWidget);
  });

  testWidgets('hides the date row when showDate is false, even with a createdAt', (
    tester,
  ) async {
    printTestDivider(
      'hides the date row when showDate is false, even with a createdAt',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        BlogMetaInfo(
          blog: blog(createdAt: '2026-08-01 10:00:00'),
          showDate: false,
        ),
      ),
    );

    printTestLog('date text → expected: not found');
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('hides the date row when showDate is true but createdAt is empty', (
    tester,
  ) async {
    printTestDivider(
      'hides the date row when showDate is true but createdAt is empty',
    );
    await tester.pumpWidget(
      pumpTestWidget(BlogMetaInfo(blog: blog(), showDate: true)),
    );

    printTestLog('date text → expected: not found');
    expect(find.textContaining('2026'), findsNothing);
  });
}
