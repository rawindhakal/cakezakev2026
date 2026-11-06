import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/auth/screens/sign_in_screen.dart';
import 'package:deliveryboy/features/home/screens/dashboard_screen.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_skeleton_loader.dart';
import 'package:deliveryboy/features/home/widgets/home_header.dart';
import 'package:deliveryboy/features/home/widgets/home_overview_section.dart';
import 'package:deliveryboy/features/home/widgets/home_performance_section.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/home_fixtures.dart';

/// The home dashboard end to end: real HomeScreen, real cubits and
/// repositories, only the network faked. `AuthTestApp.mainScreenBuilder`
/// mounts HomeScreen directly rather than the full MainScreen, so the other
/// tabs' startup work stays out of these tests.
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
    // Home is only reachable with a session, so every test starts logged in.
    await AuthHiveBox.instance.saveLoginData(
      auth: AuthModel.fromJson(loginResponseFixture),
    );
    adapter = _adapterWith();
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

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      const AuthTestApp(
        initialRoute: RouteNames.main,
        mainScreenBuilder: _homeScreenBuilder,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the dashboard loads and renders both sections', (tester) async {
    await pumpHome(tester);
    await waitForResponse(tester);

    // Note: the loading skeleton isn't asserted here — against the fake
    // adapter the response can land before the first pump completes, making it
    // a race. The loading state is covered by the widget test instead.

    expect(adapter.requestedPaths, contains(ApiEndpoints.dashboard));
    expect(find.byType(HomePerformanceSection), findsOneWidget);
    expect(find.byType(HomeOverviewSection), findsOneWidget);
    expect(find.byType(DashboardSkeletonLoader), findsNothing);
  });

  testWidgets('the dashboard requests the last-7-days trend window by default', (
    tester,
  ) async {
    await pumpHome(tester);
    await waitForResponse(tester);

    expect(adapter.trendQueries, contains('7'));
  });

  testWidgets('the header reflects the status returned by the server', (
    tester,
  ) async {
    adapter = _adapterWith(status: 1);
    ApiClient().httpClientAdapter = adapter;

    await pumpHome(tester);
    await waitForResponse(tester);

    final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
    expect(header.isOnline, isTrue);
    expect(header.name, 'Alex Johnson');
  });

  testWidgets('an offline rider is shown as offline', (tester) async {
    adapter = _adapterWith(status: 3);
    ApiClient().httpClientAdapter = adapter;

    await pumpHome(tester);
    await waitForResponse(tester);

    final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
    expect(header.isOnline, isFalse);
  });

  testWidgets('confirming the status toggle persists the new status', (
    tester,
  ) async {
    adapter = _adapterWith(status: 1);
    ApiClient().httpClientAdapter = adapter;

    await pumpHome(tester);
    await waitForResponse(tester);

    tester.widget<HomeHeader>(find.byType(HomeHeader)).onToggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppConfirmDialog), findsOneWidget);
    await tester.tap(
      find.text(
        LocalizationService.instance.translate(LanguageLabelKeys.goOffline),
      ),
    );
    await waitForResponse(tester);

    expect(
      adapter.requestedPaths,
      contains(ApiEndpoints.updateDeliveryBoyStatus),
    );
    // 3 == offline.
    expect(adapter.updatedStatuses, contains(3));
    final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
    expect(header.isOnline, isFalse);
  });

  testWidgets('a blocked account raises the blocking dialog', (tester) async {
    adapter = _adapterWith(status: 4, remark: 'Documents expired');
    ApiClient().httpClientAdapter = adapter;

    await pumpHome(tester);
    await waitForResponse(tester);

    expect(
      find.text(
        LocalizationService.instance.translate(LanguageLabelKeys.accountBlocked),
      ),
      findsOneWidget,
    );
    expect(find.text('Documents expired'), findsOneWidget);
  });

  testWidgets('acknowledging the blocked dialog clears the session and returns to sign-in', (
    tester,
  ) async {
    adapter = _adapterWith(status: 4, remark: 'Documents expired');
    ApiClient().httpClientAdapter = adapter;

    await pumpHome(tester);
    await waitForResponse(tester);

    await tester.tap(
      find.text(LocalizationService.instance.translate(LanguageLabelKeys.ok)),
    );
    await waitForResponse(tester);

    expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('a failed dashboard fetch shows the error state without crashing', (
    tester,
  ) async {
    adapter = FakeApiAdapter({
      ApiEndpoints.dashboard: (_) => {
        'status': 0,
        'message': 'Dashboard unavailable',
      },
      ApiEndpoints.getDeliveryBoyStatus: (_) => {
        'status': 1,
        'data': {'status': 1, 'remark': null},
      },
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpHome(tester);
    await waitForResponse(tester);

    // Regression guard for the SliverFillRemaining/LayoutBuilder crash: the
    // error branch used to throw during layout instead of rendering.
    expect(find.text('Dashboard unavailable'), findsOneWidget);
    expect(find.byType(HomeHeader), findsOneWidget);
  });
}

Widget _homeScreenBuilder(BuildContext context) => const HomeScreen();

/// Builds an adapter serving the dashboard plus the endpoints HomeScreen's
/// `initState` fires alongside it, with the rider's status configurable.
FakeApiAdapter _adapterWith({int status = 1, String? remark}) {
  return FakeApiAdapter({
    ApiEndpoints.dashboard: (_) => dashboardResponseFixture,
    ApiEndpoints.getDeliveryBoyStatus: (_) => {
      'status': 1,
      'data': {'status': status, 'remark': remark},
    },
    ApiEndpoints.updateDeliveryBoyStatus: (_) => {
      'status': 1,
      'message': 'Status updated',
    },
    ApiEndpoints.logout: (_) => {'status': 1, 'message': 'Logged out'},
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
    ApiEndpoints.editProfile: (_) => loginResponseFixture,
  });
}

extension on FakeApiAdapter {
  /// Every `trend` query the dashboard endpoint was called with.
  List<String> get trendQueries => requests
      .where((r) => r.path == ApiEndpoints.dashboard)
      .map((r) => r.queryParameters['trend']?.toString() ?? '')
      .toList();

  /// Every status value sent to the update-status endpoint.
  List<int> get updatedStatuses => requests
      .where((r) => r.path == ApiEndpoints.updateDeliveryBoyStatus)
      .map((r) => (r.data as Map)[ApiParameters.status] as int)
      .toList();
}
