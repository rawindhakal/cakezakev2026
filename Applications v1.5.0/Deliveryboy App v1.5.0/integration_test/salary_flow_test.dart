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
import 'package:deliveryboy/features/salary/widgets/salary_card.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/salary_fixtures.dart';

/// The salary screen end to end: real router, real screen, real cubit and
/// repository, only the network faked. Mounted directly at
/// `RouteNames.salary` (the route `AppRouter` wires with its own
/// `BlocProvider<SalaryCubit>`) rather than through `MainScreen`, to keep
/// this feature's test inside its own boundary.
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
      const AuthTestApp(initialRoute: RouteNames.salary),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loads the first page of salary payments', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.salary));
    expect(find.byType(SalaryCard), findsNWidgets(3));
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
        .where((p) => p == ApiEndpoints.salary)
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
        .where((p) => p == ApiEndpoints.salary)
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

    expect(find.byType(SalaryCard), findsWidgets);

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
      adapter.requests
          .where((r) => r.path == ApiEndpoints.salary)
          .map((r) => r.queryParameters[ApiParameters.offset])
          .any((offset) => (offset is int ? offset : int.tryParse('$offset') ?? 0) > 0),
      isTrue,
    );
  });

  testWidgets('tapping an entry with a note opens the detail sheet', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    // The first entry (id 701) carries a note.
    await tester.tap(find.byType(SalaryCard).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('August 2026 salary'), findsOneWidget);
  });
}

// The offline-screen swap is exercised in the widget test
// (salary_screen_test.dart) with a mocked ConnectivityCubit — driving a real
// disconnect here would need faking the connectivity_plus platform channel,
// which buys nothing this feature's tests don't already cover.

/// Serves page 1 by default and page 2 once the offset moves past it, so one
/// adapter covers both the initial load and the pagination journey.
FakeApiAdapter _pagedAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.salary: (options) {
      final offset =
          int.tryParse(options.queryParameters[ApiParameters.offset]?.toString() ?? '0') ??
          0;
      return offset > 0 ? salaryPage2Fixture : salaryPage1Fixture;
    },
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
  });
}
