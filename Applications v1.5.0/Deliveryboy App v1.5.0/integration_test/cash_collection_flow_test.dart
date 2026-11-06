import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_card.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/cash_collection_fixtures.dart';
import 'helpers/fake_api_adapter.dart';

/// The cash-collection screen end to end: real router, real screen, real
/// cubit and repository, only the network faked. Mounted directly at
/// `RouteNames.cashCollection` (the route `AppRouter` wires with its own
/// `BlocProvider<CashCollectionCubit>`) rather than through `MainScreen`, to
/// keep this feature's test inside its own boundary.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(authBox);
    await Hive.openBox(settingsBox);
    await LocalizationService.instance.loadFromAssets();
  });

  setUp(() async {
    await Hive.box(authBox).clear();
    await AuthHiveBox.instance.saveLoginData(
      auth: AuthModel.fromJson(loginResponseFixture),
    );
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
    await tester.pumpWidget(
      const AuthTestApp(initialRoute: RouteNames.cashCollection),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loads the first page and shows the summary totals', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.cashCollection));
    expect(find.byType(CashCollectionCard), findsNWidgets(3));
    expect(find.textContaining('1245.50'), findsOneWidget);
    expect(find.textContaining('8420.75'), findsOneWidget);
  });

  testWidgets('applying a search filter narrows the list', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.byKey(const ValueKey('searchBtn')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'TXN-000301');
    // Debouncer defaults to 500ms.
    await tester.pump(const Duration(milliseconds: 600));
    await waitForResponse(tester);

    expect(find.byType(CashCollectionCard), findsOneWidget);
    expect(
      adapter.requests.last.queryParameters[ApiParameters.search],
      'TXN-000301',
    );
  });

  testWidgets('pull to refresh refetches the first page', (tester) async {
    // With a viewport tall enough to fit all 3 cards the list never leaves
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
        .where((p) => p == ApiEndpoints.cashCollection)
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
        .where((p) => p == ApiEndpoints.cashCollection)
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

    expect(find.byType(CashCollectionCard), findsWidgets);

    final gesture = await tester.startGesture(const Offset(250, 250));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pump();
    await waitForResponse(tester);

    // ListView.builder only keeps visible items mounted, so after scrolling
    // the exact visible set (and whether page 2's cards are laid out yet)
    // isn't a stable thing to assert on — the request the app actually sent
    // is: a follow-up fetch with a non-zero offset, i.e. loadMore rather
    // than another fetchInitial.
    expect(
      adapter.requests
          .where((r) => r.path == ApiEndpoints.cashCollection)
          .map((r) => r.queryParameters[ApiParameters.offset])
          .any((offset) => (offset is int ? offset : int.tryParse('$offset') ?? 0) > 0),
      isTrue,
    );
  });
}

// The offline-screen swap is exercised in the widget test
// (cash_collection_screen_test.dart) with a mocked ConnectivityCubit —
// driving a real disconnect here would need faking the connectivity_plus
// platform channel, which buys nothing this feature's tests don't already
// cover.

/// Serves page 1 by default, page 2 once the offset moves past it, and a
/// single-item filtered result once a search term is present — so one
/// adapter covers the initial load, pagination, and filtering journeys.
FakeApiAdapter _pagedAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.cashCollection: (options) {
      final search = options.queryParameters[ApiParameters.search];
      if (search != null && search.toString().isNotEmpty) {
        return cashCollectionsFilteredFixture;
      }
      final offset =
          int.tryParse(options.queryParameters[ApiParameters.offset]?.toString() ?? '0') ??
          0;
      return offset > 0 ? cashCollectionsPage2Fixture : cashCollectionsPage1Fixture;
    },
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
  });
}
