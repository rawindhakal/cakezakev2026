import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/commons/widgets/slide_to_confirm_button.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/main/screens/main_screen.dart';
import 'package:deliveryboy/features/main/widgets/bottom_navigation.dart';
import 'package:deliveryboy/features/orders/screens/order_detail_screen.dart';
import 'package:deliveryboy/features/orders/screens/orders_screen.dart';
import 'package:deliveryboy/features/orders/widgets/order_card.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/home_fixtures.dart';
import 'helpers/orders_fixtures.dart';
import 'helpers/splash_fixtures.dart';

/// The quick-order feature end to end: real router, real screens (the tab
/// shell, the orders list, the detail screen), real cubits and repository,
/// only the network faked. Mounted through `MainScreen` (like
/// `main_flow_test.dart`) rather than at a standalone route, because
/// `OrdersScreen` only exists as the "My Delivery" tab — there's no
/// `RouteNames` entry that opens it directly. The primary journey: list →
/// detail → advance status → back to the refreshed list.
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
    adapter = _ordersAdapter();
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

  Future<void> pumpMain(WidgetTester tester) async {
    await tester.pumpWidget(
      AuthTestApp(
        initialRoute: RouteNames.main,
        mainScreenBuilder: (_) => const MainScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitForResponse(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavBar),
        matching: find.text('My Delivery'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await waitForResponse(tester);
  }

  /// Drags the slide-to-confirm track all the way across.
  Future<void> slideToConfirm(WidgetTester tester) async {
    final track = find.byType(SlideToConfirmButton);
    final rect = tester.getRect(track);
    final gesture = await tester.startGesture(
      Offset(rect.left + 8, rect.center.dy),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'lists a quick order, opens its detail, and advances its status',
    (tester) async {
      await pumpMain(tester);

      expect(find.byType(OrdersScreen), findsOneWidget);
      expect(adapter.requestedPaths, contains(ApiEndpoints.orders));
      expect(find.byType(OrderCard), findsOneWidget);
      expect(find.textContaining('SB-ORD-00512'), findsOneWidget);

      // list -> detail
      await tester.tap(find.byType(OrderCard));
      await tester.pump();
      await waitForResponse(tester);

      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(adapter.requestedPaths, contains(ApiEndpoints.orderById));
      expect(adapter.requestedPaths, contains(ApiEndpoints.orderStatuses));
      // The app bar's id line repeats the order number the list card showed.
      expect(find.textContaining('SB-ORD-00512'), findsWidgets);

      // detail -> action: slide to advance from Out For Delivery to Delivered.
      expect(find.byType(SlideToConfirmButton), findsOneWidget);
      await slideToConfirm(tester);
      await waitForResponse(tester);

      // result: the update_status call went out with the next status (6),
      // and the detail reloads to reflect it.
      expect(adapter.requestedPaths, contains(ApiEndpoints.updateStatus));
      final updateRequest = adapter.requests.firstWhere(
        (r) => r.path == ApiEndpoints.updateStatus,
      );
      expect(updateRequest.data['status_id'].toString(), '6');
      expect(find.text('Delivered'), findsWidgets);

      // back to the (now stale, unrefreshed) list — still shows the card.
      // CustomAppBar's leading control is a plain IconButton, not a
      // BackButton/CupertinoNavigationBarBackButton, so tester.pageBack()
      // (which only looks for those two) can't find it — tap it directly.
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OrdersScreen), findsOneWidget);
      expect(find.byType(OrderCard), findsOneWidget);
    },
  );

  testWidgets('shows the no-orders empty state when the list comes back empty', (
    tester,
  ) async {
    adapter = _ordersAdapter(orders: emptyOrdersListFixture);
    ApiClient().httpClientAdapter = adapter;

    await pumpMain(tester);

    expect(find.byType(OrderCard), findsNothing);
  });
}

/// Answers the shell endpoints every tab reaches on startup (same as
/// `main_flow_test.dart`'s adapter) plus the orders-tab and order-detail
/// endpoints this flow actually exercises.
FakeApiAdapter _ordersAdapter({Map<String, dynamic>? orders}) {
  var activeStatus = 5;
  return FakeApiAdapter({
    ApiEndpoints.dashboard: (_) => dashboardResponseFixture,
    ApiEndpoints.orders: (_) => orders ?? ordersListFixture,
    ApiEndpoints.ecomOrders: (_) => emptyOrdersListFixture,
    ApiEndpoints.returnRequests: (_) => emptyOrdersListFixture,
    ApiEndpoints.orderById: (_) => orderDetailFixture(activeStatus: activeStatus),
    ApiEndpoints.orderStatuses: (_) => orderStatusesFixture,
    ApiEndpoints.updateStatus: (options) {
      activeStatus = int.parse(options.data['status_id'].toString());
      return updateStatusFixture;
    },
    ApiEndpoints.settings: (_) => settingsResponseFixture,
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
    ApiEndpoints.countries: (_) => emptyOrdersListFixture,
    ApiEndpoints.editProfile: (_) => loginResponseFixture,
    ApiEndpoints.getDeliveryBoyStatus: (_) => {'status': 1, 'data': {'status': 1}},
    ApiEndpoints.addFcmToken: (_) => {'status': 1, 'message': 'Token added'},
    ApiEndpoints.systemLanguages: (_) => systemLanguagesListFixture,
  });
}
