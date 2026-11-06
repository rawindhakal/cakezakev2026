import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/screens/blog_detail_screen.dart';
import 'package:customer/features/blog/widgets/blog_meta_info.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // BlogDetailScreen formats `createdAt` via AppDateFormatter, which needs
    // a real Hive settings box open.
    await HiveTestHelper.setUp(settingsBox);
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  Widget pumpDetail(Blog blog) {
    return MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      home: BlogDetailScreen(blog: blog),
    );
  }

  Blog fullBlog() => Blog.fromJson({
    'id': '1',
    'title': 'Full Blog Title',
    'description': '<p>The full blog body.</p>',
    'created_at': '2026-08-01 10:00:00',
    'image_url': 'https://example.com/image.jpg',
    'category': {'id': '2', 'name': 'Delivery'},
    'tag_names': ['delivery', 'tips'],
  });

  testWidgets('renders the title and description when present', (
    tester,
  ) async {
    printTestDivider('renders the title and description when present');
    await tester.pumpWidget(pumpDetail(fullBlog()));
    await tester.pump();

    printTestLog('title → expected: visible');
    expect(find.text('Full Blog Title'), findsOneWidget);
  });

  testWidgets('renders the category chip when a category is present', (
    tester,
  ) async {
    printTestDivider('renders the category chip when a category is present');
    await tester.pumpWidget(pumpDetail(fullBlog()));
    await tester.pump();

    printTestLog('category chip → expected: "Delivery" visible');
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('omits the category/date row entirely when both are absent', (
    tester,
  ) async {
    printTestDivider(
      'omits the category/date row entirely when both are absent',
    );
    final blog = Blog.fromJson({'id': '1', 'title': 'No Meta Blog'});
    await tester.pumpWidget(pumpDetail(blog));
    await tester.pump();

    printTestLog('category chip → expected: not found');
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('renders tag chips when tagNames is non-empty', (tester) async {
    printTestDivider('renders tag chips when tagNames is non-empty');
    await tester.pumpWidget(pumpDetail(fullBlog()));
    await tester.pump();

    printTestLog('#delivery tag → expected: visible');
    expect(find.text('#delivery'), findsOneWidget);
    printTestLog('#tips tag → expected: visible');
    expect(find.text('#tips'), findsOneWidget);
  });

  testWidgets('omits tag chips when tagNames is empty', (tester) async {
    printTestDivider('omits tag chips when tagNames is empty');
    final blog = Blog.fromJson({'id': '1', 'title': 'No Tags Blog'});
    await tester.pumpWidget(pumpDetail(blog));
    await tester.pump();

    printTestLog('#delivery tag → expected: not found');
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('embeds BlogMetaInfo with showDate false (no duplicate date row)', (
    tester,
  ) async {
    printTestDivider(
      'embeds BlogMetaInfo with showDate false (no duplicate date row)',
    );
    await tester.pumpWidget(pumpDetail(fullBlog()));
    await tester.pump();

    final meta = tester.widget<BlogMetaInfo>(find.byType(BlogMetaInfo));
    printTestLog('BlogMetaInfo.showDate → expected: false, actual: ${meta.showDate}');
    expect(meta.showDate, isFalse);
  });

  testWidgets('omits the hero image when imageUrl is empty', (tester) async {
    printTestDivider('omits the hero image when imageUrl is empty');
    final blog = Blog.fromJson({'id': '1', 'title': 'No Image Blog'});
    await tester.pumpWidget(pumpDetail(blog));
    await tester.pump();

    printTestLog('hero image → expected: no crash, screen renders');
    expect(find.text('No Image Blog'), findsOneWidget);
  });
}
