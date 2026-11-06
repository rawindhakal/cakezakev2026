import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/faq/widgets/faq_tile.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/fake_api_adapter.dart';
import 'helpers/faq_fixtures.dart';
import 'helpers/faq_test_app.dart';

/// The FAQ screen end to end: real router, real screen, real cubit and
/// repository, only the network faked. Mounted directly at `RouteNames.faq`
/// (the route `AppRouter` wires with its own `BlocProvider<FaqCubit>`) via
/// the minimal `FaqTestApp` harness — this feature needs no auth session,
/// unlike delivery-boy's equivalent flows. `settingsBox`/`authBox` still need
/// opening though: `ApiClient._withLangHeader` reads
/// `SettingsHiveBox.instance.languageCode` on every request, and
/// `DioInterceptor.onRequest` reads `AuthHiveBox.instance.getToken()` for
/// every endpoint outside its no-auth allowlist (faq included, since it isn't
/// a login/register/forgot-password endpoint) even though it doesn't require
/// login to succeed.
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
    await tester.pumpWidget(const FaqTestApp());
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loads the first page of faqs', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.faq));
    expect(find.byType(FaqTile), findsNWidgets(2));
  });

  testWidgets('tapping a tile expands it and shows the answer', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.byType(FaqTile).first);
    await tester.pump();

    expect(
      find.text(
        'Open Orders from your profile and tap any order to see its live status.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh refetches the first page', (tester) async {
    // With a viewport tall enough to fit both tiles the list never leaves
    // its idle scroll state and a fling is a silent no-op — shrink it so the
    // list can actually move, and drive the gesture by hand since fling can
    // finish before the RefreshIndicator arms.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 500);
    tester.view.devicePixelRatio = 1.0;

    await pumpScreen(tester);
    await waitForResponse(tester);

    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.faq)
        .length;

    final gesture = await tester.startGesture(const Offset(250, 250));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pump();
    await waitForResponse(tester);

    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.faq)
        .length;
    expect(after, greaterThan(before));
  });

  testWidgets('scrolling near the bottom loads the next page', (
    tester,
  ) async {
    // Same reasoning as the refresh test: a short viewport makes the list
    // actually scrollable, and a driven drag (rather than fling) reliably
    // crosses the loadMore threshold near the bottom.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 500);
    tester.view.devicePixelRatio = 1.0;

    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(find.byType(FaqTile), findsWidgets);

    final gesture = await tester.startGesture(const Offset(250, 250));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pump();
    await waitForResponse(tester);

    // ListView.builder only keeps visible items mounted, so after scrolling
    // the exact visible set isn't a stable thing to assert on — the request
    // the app actually sent is: a follow-up fetch with a non-zero offset,
    // i.e. fetchMore rather than another fetchInitial.
    expect(
      adapter.requests
          .where((r) => r.path == ApiEndpoints.faq)
          .map((r) => r.queryParameters[ApiParameters.offset])
          .any(
            (offset) =>
                (offset is int ? offset : int.tryParse('$offset') ?? 0) > 0,
          ),
      isTrue,
    );
  });
}

// The offline-view swap is exercised in the widget test (faq_screen_test.dart)
// with a mocked ConnectivityCubit — driving a real disconnect here would need
// faking the connectivity_plus platform channel, which buys nothing this
// feature's tests don't already cover.

/// Serves page 1 by default and page 2 once the offset moves past it, so one
/// adapter covers both the initial load and the pagination journey.
FakeApiAdapter _pagedAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.faq: (options) {
      final offset =
          int.tryParse(
            options.queryParameters[ApiParameters.offset]?.toString() ?? '0',
          ) ??
          0;
      return offset > 0 ? faqPage2Fixture : faqPage1Fixture;
    },
  });
}
