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
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_transaction_item.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/wallet_fixtures.dart';

/// The wallet screen end to end: real router, real screen, real cubit and
/// repository, only the network faked. Mounted directly at
/// `RouteNames.wallet` (the route `AppRouter` wires with its own
/// `BlocProvider<WalletCubit>`) rather than through `MainScreen`, to keep
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
    adapter = _walletAdapter();
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
      const AuthTestApp(initialRoute: RouteNames.wallet),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('loads the balance and transaction list', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.getWithdrawalRequests));
    expect(find.byType(WalletTransactionItem), findsNWidgets(3));
    expect(find.textContaining('4521'), findsOneWidget);
  });

  testWidgets('applying a status filter narrows the list', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    // The filter button is the only IconButton whose icon is the filter
    // AppSvgIcon asset (the app bar's other IconButton starts search).
    final filterButton = find.byWidgetPredicate(
      (w) =>
          w is IconButton &&
          w.icon is AppSvgIcon &&
          (w.icon as AppSvgIcon).path == AssetsConstants.filterIcon,
    );
    await tester.tap(filterButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // A transaction row can itself carry a "Pending" status label, so the
    // filter sheet's own "Pending" option is not necessarily the only match.
    await tester.tap(find.text('Pending').last);
    await tester.pump();
    await waitForResponse(tester);

    expect(find.byType(WalletTransactionItem), findsOneWidget);
    expect(
      adapter.requests.last.queryParameters[ApiParameters.status],
      '0',
    );
  });

  testWidgets('pull to refresh refetches the wallet', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 500);
    tester.view.devicePixelRatio = 1.0;

    await pumpScreen(tester);
    await waitForResponse(tester);

    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.getWithdrawalRequests)
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
        .where((p) => p == ApiEndpoints.getWithdrawalRequests)
        .length;
    expect(after, greaterThan(before));
  });

  testWidgets('opening a transaction with a message shows its detail sheet', (
    tester,
  ) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    // The pending request (id 501) carries a message.
    await tester.tap(find.byType(WalletTransactionItem).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Need cash for fuel'), findsOneWidget);
  });

  testWidgets('a successful withdrawal reloads the wallet', (tester) async {
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.text('Withdraw'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextFormField).at(0), '500');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.addWithdrawalRequest));
    expect(
      find.text('Withdrawal request submitted successfully'),
      findsOneWidget,
    );
  });

  testWidgets('a rejected withdrawal surfaces the server error and keeps the sheet open', (
    tester,
  ) async {
    adapter = FakeApiAdapter({
      ApiEndpoints.getWithdrawalRequests: (_) => walletRequestsFixture,
      ApiEndpoints.addWithdrawalRequest: (_) => withdrawalRequestRejectedFixture,
      ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
      ApiEndpoints.countrySettings: (_) => {
        'status': 1,
        'data': {'currency': '₹'},
      },
    });
    ApiClient().httpClientAdapter = adapter;
    await pumpScreen(tester);
    await waitForResponse(tester);

    await tester.tap(find.text('Withdraw'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextFormField).at(0), '999999');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await waitForResponse(tester);

    expect(find.text('Withdrawal amount exceeds balance'), findsOneWidget);
    // Sheet stays open — the submit button is still there.
    expect(find.text('Submit'), findsOneWidget);
  });
}

/// Serves the full request list by default and a single pending request once
/// a `status` filter is present, so one adapter covers loading, filtering,
/// and the withdrawal-submit journeys.
FakeApiAdapter _walletAdapter() {
  return FakeApiAdapter({
    ApiEndpoints.getWithdrawalRequests: (options) {
      final status = options.queryParameters[ApiParameters.status];
      if (status != null && status.toString().isNotEmpty) {
        return walletRequestsPendingFixture;
      }
      return walletRequestsFixture;
    },
    ApiEndpoints.addWithdrawalRequest: (_) => withdrawalRequestSuccessFixture,
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
  });
}
