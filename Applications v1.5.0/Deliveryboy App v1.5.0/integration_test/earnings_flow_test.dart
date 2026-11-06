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
import 'package:deliveryboy/features/earnings/widgets/earnings_quick_access_section.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_summary_card.dart';
import 'package:deliveryboy/features/salary/screens/salary_screen.dart';
import 'package:deliveryboy/features/wallet/screens/wallet_screen.dart';
import 'package:deliveryboy/features/cash_collection/screens/cash_collection_screen.dart';
import 'package:deliveryboy/features/settlement_history/screens/settlement_history_screen.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/home_fixtures.dart';

/// The earnings screen end to end: real router, real screen, and — since
/// EarningsScreen has no repository/cubit of its own (it was refactored to
/// reuse home's DashboardCubit/DashboardModel directly) — the real
/// DashboardCubit and DashboardRepository, with only the network faked.
/// Mounted directly at `RouteNames.earnings` rather than through `MainScreen`,
/// to keep this feature's test inside its own boundary (see TESTING.md's
/// "keep a feature's integration test inside that feature's boundary"
/// gotcha).
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
    adapter = FakeApiAdapter({
      ApiEndpoints.dashboard: (_) => dashboardResponseFixture,
    });
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
      const AuthTestApp(initialRoute: RouteNames.earnings),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loads the dashboard and renders the summary and quick-access sections', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.dashboard));
    expect(find.byType(EarningsSummaryCard), findsOneWidget);
    expect(find.byType(EarningsQuickAccessSection), findsOneWidget);
    // Total earning from the fixture's wallet.total_earned.
    expect(find.textContaining('20862.95'), findsOneWidget);
  });

  testWidgets('pull to refresh refetches the dashboard', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;

    await tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await waitForResponse(tester);

    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.dashboard)
        .length;
    expect(after, greaterThan(before));
  });

  testWidgets('tapping the wallet tile navigates to the wallet screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.text('Wallet'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WalletScreen), findsOneWidget);
  });

  testWidgets('tapping the salary tile navigates to the salary screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.text('Salary'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SalaryScreen), findsOneWidget);
  });

  testWidgets('tapping the cash-collection tile navigates to cash collection', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.text('Cash Collection'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CashCollectionScreen), findsOneWidget);
  });

  testWidgets(
    'tapping the settlement-history tile navigates to settlement history',
    (tester) async {
      await pumpScreen(tester);
      await waitForResponse(tester);

      await tester.tap(find.text('Settlement History'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettlementHistoryScreen), findsOneWidget);
    },
  );
}
