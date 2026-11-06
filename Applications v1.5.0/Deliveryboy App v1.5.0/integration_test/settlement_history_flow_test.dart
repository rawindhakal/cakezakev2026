import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_card.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/settlement_history_fixtures.dart';

/// The settlement history screen end to end: real router, real screen, real
/// cubit and repository, only the network faked. Mounted directly at
/// `RouteNames.settlementHistory` (the route `AppRouter` wires with its own
/// `BlocProvider<SettlementHistoryCubit>`) rather than through the earnings
/// screen that links to it, to keep this feature's test inside its own
/// boundary.
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

  // The screen's filter IconButton carries no tooltip, so it is located
  // through the SVG asset it renders.
  final filterButton = find.ancestor(
    of: find.byWidgetPredicate(
      (w) => w is AppSvgIcon && w.path == AssetsConstants.filterIcon,
    ),
    matching: find.byType(IconButton),
  );

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
      const AuthTestApp(initialRoute: RouteNames.settlementHistory),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  List<RecordedRequest> settlementRequests() => adapter.requests
      .where((r) => r.path == ApiEndpoints.settlementHistory)
      .toList();

  testWidgets('loads the first page of settlement entries', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.settlementHistory));
    expect(find.byType(SettlementHistoryCard), findsNWidgets(3));
    // No filters applied on entry, so none are sent.
    final query = settlementRequests().first.queryParameters;
    expect(query.containsKey(ApiParameters.search), isFalse);
    expect(query.containsKey(ApiParameters.entryType), isFalse);
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

    final before = settlementRequests().length;

    final gesture = await tester.startGesture(const Offset(250, 250));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pump();
    await waitForResponse(tester);

    expect(settlementRequests().length, greaterThan(before));
  });

  testWidgets('scrolling near the bottom loads the next page', (tester) async {
    // Same reasoning as the refresh test: a short viewport makes the list
    // actually scrollable, and a driven drag (rather than fling) reliably
    // crosses the loadMore threshold near the bottom.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 500);
    tester.view.devicePixelRatio = 1.0;

    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(find.byType(SettlementHistoryCard), findsWidgets);

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
    // i.e. loadMore rather than another fetchInitial.
    expect(
      settlementRequests()
          .map((r) => r.queryParameters[ApiParameters.offset])
          .any(
            (offset) =>
                (offset is int ? offset : int.tryParse('$offset') ?? 0) > 0,
          ),
      isTrue,
    );
  });

  testWidgets('tapping an entry opens its detail sheet', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    // The first entry (id 901) carries a message alongside its balances.
    await tester.tap(find.byType(SettlementHistoryCard).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Commission for order #1006'), findsOneWidget);
    expect(find.text('₹1200.0'), findsOneWidget);
    expect(find.text('₹1350.75'), findsOneWidget);
  });

  testWidgets('searching refetches with the query and shows the filtered page', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.byKey(const ValueKey('searchBtn')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '902');
    // Debouncer defaults to 500ms.
    await tester.pump(const Duration(milliseconds: 600));
    await waitForResponse(tester);

    expect(
      settlementRequests()
          .map((r) => r.queryParameters[ApiParameters.search])
          .contains('902'),
      isTrue,
    );
    expect(find.byType(SettlementHistoryCard), findsOneWidget);
  });

  testWidgets('applying an entry-type filter sends it and lights the badge', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(filterButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(LocalizationService.instance.translate(
      LanguageLabelKeys.withdrawal,
    )));
    await tester.pump();
    await tester.tap(find.text(LocalizationService.instance.translate(
      LanguageLabelKeys.apply,
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await waitForResponse(tester);

    expect(
      settlementRequests()
          .map((r) => r.queryParameters[ApiParameters.entryType])
          .contains('withdrawal'),
      isTrue,
    );
    expect(find.byType(SettlementHistoryCard), findsOneWidget);
    // The active-filter dot is the Positioned sibling of the IconButton.
    expect(
      find.descendant(
        of: find.ancestor(of: filterButton, matching: find.byType(Stack)).first,
        matching: find.byType(Positioned),
      ),
      findsOneWidget,
    );
  });

  testWidgets('clearing filters from the sheet reloads the unfiltered page', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(filterButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(LocalizationService.instance.translate(
      LanguageLabelKeys.withdrawal,
    )));
    await tester.pump();
    await tester.tap(find.text(LocalizationService.instance.translate(
      LanguageLabelKeys.apply,
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await waitForResponse(tester);

    expect(find.byType(SettlementHistoryCard), findsOneWidget);

    await tester.tap(filterButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(LocalizationService.instance.translate(
      LanguageLabelKeys.clear,
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await waitForResponse(tester);

    expect(find.byType(SettlementHistoryCard), findsNWidgets(3));
    expect(settlementRequests().last.queryParameters.containsKey(
      ApiParameters.entryType,
    ), isFalse);
  });
}

// The offline-screen swap is exercised in the widget test
// (settlement_history_screen_test.dart) with a mocked ConnectivityCubit —
// driving a real disconnect here would need faking the connectivity_plus
// platform channel, which buys nothing this feature's tests don't already
// cover.

/// Serves the filtered page whenever a search or entry-type filter is set,
/// page 2 once the offset moves past the first page, and page 1 otherwise —
/// so one adapter covers the initial load, pagination and both filter paths.
FakeApiAdapter _pagedAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.settlementHistory: (options) {
      final query = options.queryParameters;
      final hasFilter =
          (query[ApiParameters.search]?.toString().isNotEmpty ?? false) ||
          (query[ApiParameters.entryType]?.toString().isNotEmpty ?? false);
      if (hasFilter) return settlementHistoryFilteredFixture;
      final offset =
          int.tryParse(query[ApiParameters.offset]?.toString() ?? '0') ?? 0;
      return offset > 0
          ? settlementHistoryPage2Fixture
          : settlementHistoryPage1Fixture;
    },
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
  });
}
