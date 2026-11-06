import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/screens/blog_detail_screen.dart';
import 'package:customer/features/blog/widgets/blog_card.dart';
import 'package:customer/features/blog/widgets/category_filter_bar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/fake_api_adapter.dart';
import 'helpers/blog_fixtures.dart';
import 'helpers/blog_test_app.dart';

/// The blog screen end to end: real router, real screens (list + detail),
/// real cubits and repository, only the network faked. Mounted directly at
/// `RouteNames.blog` via the minimal `BlogTestApp` harness, same pattern as
/// `faq_flow_test.dart`. Unlike faq, two endpoints are in flight together
/// from `BlogScreen.initState` (`blogCategories` + `blogs`) and the flows
/// exercise a second real screen (`BlogDetailScreen`) reached via
/// `RouteNames.blogDetail`, not just list interactions.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(settingsBox);
    await Hive.openBox(authBox);
  });

  setUp(() {
    adapter = _pagedAdapter();
    ApiClient().httpClientAdapter = adapter;
  });

  Future<void> waitForResponse(WidgetTester tester) async {
    // The live binding runs on real time, so pump(Duration) alone doesn't let
    // a pending network future complete.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const BlogTestApp());
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Blog cards render their own category badge with the same text as the
  // filter chip (both say "Delivery"), so a plain `find.text('Delivery')`
  // is ambiguous — `.first` landed on a card's badge in practice, which sits
  // inside the card's own GestureDetector and navigates to the detail screen
  // instead of filtering. Scope the finder to CategoryFilterBar itself.
  Finder categoryChip(String label) => find.descendant(
    of: find.byType(CategoryFilterBar),
    matching: find.text(label),
  );

  testWidgets('loads the first page of blogs and the category chips on entry', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.blogCategories));
    expect(adapter.requestedPaths, contains(ApiEndpoints.blogs));
    expect(find.byType(BlogCard), findsWidgets);
    expect(categoryChip('Delivery'), findsOneWidget);
    expect(categoryChip('Groceries'), findsOneWidget);
  });

  testWidgets(
    'tapping a category chip re-fetches with that category and replaces the list',
    (tester) async {
      await pumpScreen(tester);
      await waitForResponse(tester);

      await tester.tap(categoryChip('Delivery'));
      await tester.pump();
      await waitForResponse(tester);

      final blogRequests = adapter.requests
          .where((r) => r.path == ApiEndpoints.blogs)
          .toList();
      expect(
        blogRequests.last.queryParameters[ApiParameters.categoryId],
        '2',
      );
      expect(find.byType(BlogCard), findsNWidgets(1));
      expect(find.text('Blog Post 1'), findsOneWidget);
    },
  );

  testWidgets('tapping "All" clears the filter and re-fetches unfiltered', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(categoryChip('Delivery'));
    await tester.pump();
    await waitForResponse(tester);
    expect(find.byType(BlogCard), findsNWidgets(1));

    await tester.tap(categoryChip(LanguageLabelKeys.filterAll));
    await tester.pump();
    await waitForResponse(tester);

    final blogRequests = adapter.requests
        .where((r) => r.path == ApiEndpoints.blogs)
        .toList();
    expect(
      blogRequests.last.queryParameters.containsKey(ApiParameters.categoryId),
      isFalse,
    );
    expect(find.byType(BlogCard), findsWidgets);
  });

  testWidgets('tapping a card navigates to the detail screen for that blog', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.byType(BlogCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(BlogDetailScreen), findsOneWidget);
    final detail = tester.widget<BlogDetailScreen>(
      find.byType(BlogDetailScreen),
    );
    expect(detail.blog, isA<Blog>());
    expect(detail.blog.title, 'Blog Post 1');
    expect(find.text('Blog Post 1'), findsOneWidget);
  });

  testWidgets('scrolling near the bottom loads the next page', (
    tester,
  ) async {
    // Same reasoning as faq's equivalent test: a short viewport makes the
    // list actually scrollable, and a driven drag reliably crosses the
    // loadMore threshold near the bottom.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 500);
    tester.view.devicePixelRatio = 1.0;

    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(find.byType(BlogCard), findsWidgets);

    // Cards are much taller than faq's tiles (image + text block, ~300+px
    // each) — 10 of them make for a long list. Drive the drag on the
    // ListView itself (rather than a raw screen offset) so it lands on the
    // scrollable regardless of viewport/device-pixel-ratio quirks, and
    // repeat it since a single drag's travel is capped by the viewport
    // height.
    // The category filter bar is also a horizontal ListView — scope to the
    // vertical one (the blog list) to avoid an ambiguous finder.
    final list = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    );
    for (var i = 0; i < 15; i++) {
      await tester.drag(list, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await waitForResponse(tester);

    // ListView.builder only keeps visible items mounted, so the exact
    // mounted set isn't stable to assert on — the request the app actually
    // sent is what matters: a follow-up fetch with a non-zero offset.
    expect(
      adapter.requests
          .where((r) => r.path == ApiEndpoints.blogs)
          .map((r) => r.queryParameters[ApiParameters.offset])
          .any(
            (offset) =>
                (offset is int ? offset : int.tryParse('$offset') ?? 0) > 0,
          ),
      isTrue,
    );
  });

  testWidgets(
    'pull-to-refresh re-fetches with the currently active category filter still applied',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(500, 500);
      tester.view.devicePixelRatio = 1.0;

      await pumpScreen(tester);
      await waitForResponse(tester);

      await tester.tap(categoryChip('Delivery'));
      await tester.pump();
      await waitForResponse(tester);
      expect(find.byType(BlogCard), findsNWidgets(1));

      final gesture = await tester.startGesture(const Offset(250, 250));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pump();
      await waitForResponse(tester);

      final lastBlogRequest = adapter.requests
          .lastWhere((r) => r.path == ApiEndpoints.blogs);
      expect(lastBlogRequest.queryParameters[ApiParameters.categoryId], '2');
      expect(find.byType(BlogCard), findsNWidgets(1));
    },
  );
}

// The offline-view swap is exercised in the widget test (blog_screen_test.dart)
// with a mocked ConnectivityCubit — driving a real disconnect here would need
// faking the connectivity_plus platform channel, which buys nothing this
// feature's tests don't already cover.

/// Serves both blog endpoints: categories always the same list; blogs keyed
/// off `category_id` (filtered) and `offset` (pagination) the same way the
/// real API would be.
FakeApiAdapter _pagedAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.blogCategories: (_) => blogCategoriesFixture,
    ApiEndpoints.blogs: (options) {
      final categoryId = options.queryParameters[ApiParameters.categoryId]
          ?.toString();
      if (categoryId == '2') return blogFilteredByDeliveryFixture;
      final offset =
          int.tryParse(
            options.queryParameters[ApiParameters.offset]?.toString() ?? '0',
          ) ??
          0;
      return offset > 0 ? blogPage2Fixture : blogPage1Fixture;
    },
  });
}
