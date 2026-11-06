import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/widgets/blog_card.dart';
import 'package:customer/features/blog/widgets/blog_meta_info.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

class _FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  // BlogCard formats `createdAt` via AppDateFormatter, which reads
  // SettingsHiveBox.instance.dateFormat — needs a real Hive box open, even
  // though nothing here otherwise touches settings.
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakeRoute());
    await HiveTestHelper.setUp(settingsBox);
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  Blog fullBlog() => Blog.fromJson({
    'id': '1',
    'title': 'Full Blog Title',
    'short_description': 'A short teaser description.',
    'created_at': '2026-08-01 10:00:00',
    'category': {'id': '2', 'name': 'Delivery'},
  });

  Widget pumpCard(Blog blog, {NavigatorObserver? observer}) {
    return MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      navigatorObservers: observer != null ? [observer] : const [],
      home: Scaffold(body: BlogCard(blog: blog)),
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const SizedBox(), settings: settings),
    );
  }

  testWidgets('renders title, short description, category chip and date when present', (
    tester,
  ) async {
    printTestDivider(
      'renders title, short description, category chip and date when present',
    );
    await tester.pumpWidget(pumpCard(fullBlog()));
    await tester.pump();

    printTestLog('title → expected: visible');
    expect(find.text('Full Blog Title'), findsOneWidget);
    printTestLog('short description → expected: visible');
    expect(find.text('A short teaser description.'), findsOneWidget);
    printTestLog('category chip → expected: "Delivery" visible');
    expect(find.text('Delivery'), findsOneWidget);
    printTestLog('BlogMetaInfo → expected: 1 embedded with showDate: false');
    final meta = tester.widget<BlogMetaInfo>(find.byType(BlogMetaInfo));
    expect(meta.showDate, isFalse);
  });

  testWidgets('omits the category chip when the blog has no category', (
    tester,
  ) async {
    printTestDivider('omits the category chip when the blog has no category');
    final blog = Blog.fromJson({'id': '1', 'title': 'No Category Blog'});
    await tester.pumpWidget(pumpCard(blog));
    await tester.pump();

    printTestLog('category chip → expected: not found');
    expect(find.byType(Container), findsWidgets);
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('omits the short description row when it is empty', (
    tester,
  ) async {
    printTestDivider('omits the short description row when it is empty');
    final blog = Blog.fromJson({'id': '1', 'title': 'No Description Blog'});
    await tester.pumpWidget(pumpCard(blog));
    await tester.pump();

    printTestLog('short description → expected: not rendered');
    expect(find.textContaining('teaser'), findsNothing);
  });

  testWidgets('tapping the card navigates to blogDetail with the blog as the argument', (
    tester,
  ) async {
    printTestDivider(
      'tapping the card navigates to blogDetail with the blog as the argument',
    );
    final observer = _MockNavigatorObserver();
    final blog = fullBlog();
    await tester.pumpWidget(pumpCard(blog, observer: observer));
    await tester.pump();

    await tester.tap(find.byType(BlogCard));
    await tester.pumpAndSettle();

    final captured = verify(
      () => observer.didPush(captureAny(), any()),
    ).captured;
    final pushedRoute = captured.last as Route;
    printTestLog(
      'route name → expected: "${RouteNames.blogDetail}", actual: "${pushedRoute.settings.name}"',
    );
    expect(pushedRoute.settings.name, RouteNames.blogDetail);
    printTestLog('route argument → expected: same Blog instance');
    expect(pushedRoute.settings.arguments, same(blog));
  });
}
