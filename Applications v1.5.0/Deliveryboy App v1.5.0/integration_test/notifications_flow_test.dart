import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/notifications_fixtures.dart';

/// The notifications screen end to end: real router, real screen, real
/// cubits and repository, only the network faked. `NotificationScreen`
/// builds its own `NotificationCubit`/`NotificationSaveCubit` internally
/// (a `MultiBlocProvider` inside the widget itself, unlike
/// `cash_collection`/`wallet`/`salary`'s route-level providers), so mounting
/// it directly at `RouteNames.notifications` through `AuthTestApp` is enough
/// — no extra `BlocProvider` needed at the test's own app level.
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
    adapter = _notificationsAdapter();
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
      const AuthTestApp(initialRoute: RouteNames.notifications),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('settings load and render across all 3 tabs', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(
      adapter.requestedPaths,
      contains(ApiEndpoints.notificationPreferences),
    );
    // Email tab (default) — mail is non-null for every event in the fixture.
    expect(find.text('Order Updates'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(6));

    // Mobile (push) tab — also all non-null.
    await tester.tap(find.text('Notifications').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Switch), findsNWidgets(6));

    // SMS tab — Payments and Promotions have sms:null on every event, so
    // both categories (headers included) render nothing there.
    await tester.tap(find.text('SMS'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Order Updates'), findsOneWidget);
    expect(find.text('Payments'), findsNothing);
    expect(find.text('Promotions'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('toggling a switch then tapping Save sends the mutated preference', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    // Email tab, first switch (order_placed, mail: true) → flip to false.
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Save Settings'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Settings'));
    await tester.pump();
    await waitForResponse(tester);

    final saveRequest = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.notificationPreferences && r.data is Map,
    );
    final preferences = (saveRequest.data as Map)['preferences'] as List;
    final orderPlaced = preferences.firstWhere(
      (p) => p['key'] == 'order_placed',
    ) as Map;
    expect((orderPlaced['channels'] as Map)['mail'], isFalse);
    expect(find.text('Settings saved successfully'), findsOneWidget);
  });

  testWidgets('a save rejection surfaces the server error and leaves the toggle as set', (
    tester,
  ) async {
    adapter = FakeApiAdapter({
      ApiEndpoints.notificationPreferences: (options) {
        if (options.method == 'POST') {
          return notificationSaveRejectedFixture;
        }
        return notificationSettingsFixture;
      },
      ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
      ApiEndpoints.countrySettings: (_) => {
        'status': 1,
        'data': {'currency': '₹'},
      },
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Save Settings'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Settings'));
    await tester.pump();
    await waitForResponse(tester);

    expect(find.text('Could not save preferences'), findsOneWidget);
    // The toggle the user set stays flipped — no refetch happened to
    // overwrite it with the server's (unsaved) state.
    final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
    expect(switchWidget.value, isFalse);
  });

  testWidgets('pull to refresh refetches the settings', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 500);
    tester.view.devicePixelRatio = 1.0;

    await pumpScreen(tester);
    await waitForResponse(tester);

    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.notificationPreferences)
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
        .where((p) => p == ApiEndpoints.notificationPreferences)
        .length;
    expect(after, greaterThan(before));
  });
}

/// Answers GET with the settings fixture and POST with a success envelope,
/// so one adapter covers the load, tab, and save journeys.
FakeApiAdapter _notificationsAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.notificationPreferences: (options) {
      if (options.method == 'POST') {
        return notificationSaveSuccessFixture;
      }
      return notificationSettingsFixture;
    },
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
  });
}
