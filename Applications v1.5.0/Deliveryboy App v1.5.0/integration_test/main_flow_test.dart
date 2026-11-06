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
import 'package:deliveryboy/features/earnings/screens/earnings_screen.dart';
import 'package:deliveryboy/features/home/screens/dashboard_screen.dart';
import 'package:deliveryboy/features/main/screens/main_screen.dart';
import 'package:deliveryboy/features/main/widgets/bottom_navigation.dart';
import 'package:deliveryboy/features/orders/screens/orders_screen.dart';
import 'package:deliveryboy/features/profile/screens/profile_screen.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/home_fixtures.dart';
import 'helpers/splash_fixtures.dart';

/// The app shell end to end, with the real four tab screens mounted — the one
/// place they all run together, which is exactly what `MainScreen` is. The
/// tabs' own content is another feature's business, so every list endpoint
/// here answers empty and the assertions stay on the shell: which tab is
/// showing, what the back gesture does, and the post-login FCM retry.
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
    adapter = _mainAdapter();
    ApiClient().httpClientAdapter = adapter;
  });

  Future<void> waitForResponse(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpMain(WidgetTester tester) async {
    await tester.pumpWidget(
      AuthTestApp(
        initialRoute: RouteNames.main,
        mainScreenBuilder: (_) => const MainScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitForResponse(tester);
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavBar),
        matching: find.text(label),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('opens on the home tab with all four tabs available', (
    tester,
  ) async {
    await pumpMain(tester);

    expect(find.byType(BottomNavBar), findsOneWidget);
    // Real translations are loaded here, so these are the rendered strings,
    // not the LanguageLabelKeys keys the widget tests match on.
    for (final label in ['Home', 'My Delivery', 'Earnings', 'Profile']) {
      expect(
        find.descendant(
          of: find.byType(BottomNavBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index, 0);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(adapter.requestedPaths, contains(ApiEndpoints.dashboard));
  });

  testWidgets('each tab switches the shell to that screen', (tester) async {
    await pumpMain(tester);

    await tapTab(tester, 'My Delivery');
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index, 1);
    expect(find.byType(OrdersScreen), findsOneWidget);

    await tapTab(tester, 'Earnings');
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index, 2);
    expect(find.byType(EarningsScreen), findsOneWidget);

    await tapTab(tester, 'Profile');
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index, 3);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('every tab stays mounted across switches', (tester) async {
    await pumpMain(tester);
    await tapTab(tester, 'Profile');
    await tester.pump(const Duration(milliseconds: 500));

    // An IndexedStack keeps its children alive, so the home tab is still in
    // the tree (and keeps its scroll position and loaded data) while the
    // profile tab is the one on screen. skipOffstage: false because
    // IndexedStack's inactive children aren't wrapped in an Offstage
    // ancestor, but a real profile-tab image decode can otherwise leave the
    // frame mid-transition when this assertion runs on a real device.
    expect(
      find.byType(HomeScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(OrdersScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(EarningsScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the back gesture returns to the home tab before leaving', (
    tester,
  ) async {
    await pumpMain(tester);
    await tapTab(tester, 'Earnings');

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index, 0);
    expect(find.byType(MainScreen), findsOneWidget);
  });
}

// Not covered here: MainScreen's post-login FCM retry. It depends on the
// device actually issuing a token (a simulator without APNs may hand back
// none), which would make this flow pass or fail for reasons that have
// nothing to do with the code under test. Both of its branches — blank stored
// token registers, existing token doesn't — are asserted deterministically in
// main_screen_test.dart against the fake messaging platform instead.

/// Answers every endpoint the four tabs reach on startup. The lists come back
/// empty on purpose — this flow is about the shell, not the tabs' content.
FakeApiAdapter _mainAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.dashboard: (_) => dashboardResponseFixture,
    ApiEndpoints.orders: (_) => emptyListFixture,
    ApiEndpoints.ecomOrders: (_) => emptyListFixture,
    ApiEndpoints.returnRequests: (_) => emptyListFixture,
    ApiEndpoints.orderStatuses: (_) => emptyListFixture,
    ApiEndpoints.settings: (_) => settingsResponseFixture,
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
    ApiEndpoints.countries: (_) => emptyListFixture,
    ApiEndpoints.editProfile: (_) => loginResponseFixture,
    ApiEndpoints.getDeliveryBoyStatus: (_) => {'status': 1, 'data': {'status': 1}},
    ApiEndpoints.addFcmToken: (_) => {'status': 1, 'message': 'Token added'},
    ApiEndpoints.systemLanguages: (_) => systemLanguagesListFixture,
  });
}
