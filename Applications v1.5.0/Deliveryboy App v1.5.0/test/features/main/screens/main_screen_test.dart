import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/auth/cubit/add_fcm_token_cubit.dart';
import 'package:deliveryboy/features/home/cubit/dashboard_cubit.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';
import 'package:deliveryboy/features/main/screens/main_screen.dart';
import 'package:deliveryboy/features/main/widgets/bottom_navigation.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/firebase_test_helper.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

// Same shapes orders_screen_test.dart declares — the order cubits are generic
// over their models, so a shared MockCubit in mock_cubits.dart would have to
// import the whole orders feature for every test that uses that file.
class MockOrderCubit extends MockCubit<PaginationState<OrderData>>
    implements OrderCubit {}

class MockEcommerceOrderCubit
    extends MockCubit<PaginationState<EcommerceOrderDataModel>>
    implements EcommerceOrderCubit {}

class MockReturnOrderCubit extends MockCubit<PaginationState<ReturnRequestData>>
    implements ReturnOrderCubit {}

class MockOrderStatusListFilterCubit
    extends MockCubit<OrderStatusListFilterState>
    implements OrderStatusListFilterCubit {}

class MockReturnOrderStatusListFilterCubit
    extends MockCubit<ReturnOrderStatusListFilterState>
    implements ReturnOrderStatusListFilterCubit {}

class MockAddFcmTokenCubit extends MockCubit<AddFcmTokenState>
    implements AddFcmTokenCubit {}

/// MainScreen is a shell: a NavCubit, a bottom bar, and an IndexedStack of the
/// four tab screens. Those tabs are covered by their own features' tests, so
/// everything here runs with connectivity **disconnected** — each tab then
/// renders its own offline body instead of its real content, which keeps this
/// test on what MainScreen itself owns (tab state, the back gesture, the
/// language-change reload, and the post-login FCM token retry) rather than on
/// four other features' startup paths.
/// MainScreen's own back-gesture guard, pinned to its inferred type argument.
final _popScopeFinder = find.byType(PopScope<Object>);

void main() {
  late MockDashboardCubit dashboardCubit;
  late MockOrderCubit orderCubit;
  late MockEcommerceOrderCubit ecommerceCubit;
  late MockReturnOrderCubit returnCubit;
  late MockOrderStatusListFilterCubit statusFilterCubit;
  late MockReturnOrderStatusListFilterCubit returnStatusFilterCubit;
  late MockSettingsCubit settingsCubit;
  late MockDeliveryBoyStatusCubit statusCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late MockProfileDetailCubit profileDetailCubit;
  late MockConnectivityCubit connectivityCubit;
  late MockLanguageCubit languageCubit;
  late MockAddFcmTokenCubit addFcmTokenCubit;
  late LanguageState languageState;

  // MainScreen's initState reaches NotificationService, and EarningsScreen
  // builds a real DashboardCubit internally (no seam to inject a mock), so
  // its fetch is answered by the fake adapter instead of the network.
  setUpAll(() async {
    await FirebaseTestHelper.setUp();
    ApiClient().httpClientAdapter = FakeApiAdapter({
      ApiEndpoints.dashboard: (_) => {'status': 1, 'data': <String, dynamic>{}},
    });
  });

  tearDownAll(() {
    FirebaseTestHelper.tearDown();
    printTestDivider('=== All tests run! ===');
  });

  setUp(() async {
    // The home header reads the rider's profile out of AuthHiveBox, and the
    // FCM retry reads the stored token from it.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    dashboardCubit = MockDashboardCubit();
    orderCubit = MockOrderCubit();
    ecommerceCubit = MockEcommerceOrderCubit();
    returnCubit = MockReturnOrderCubit();
    statusFilterCubit = MockOrderStatusListFilterCubit();
    returnStatusFilterCubit = MockReturnOrderStatusListFilterCubit();
    settingsCubit = MockSettingsCubit();
    statusCubit = MockDeliveryBoyStatusCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    profileDetailCubit = MockProfileDetailCubit();
    connectivityCubit = MockConnectivityCubit();
    languageCubit = MockLanguageCubit();
    addFcmTokenCubit = MockAddFcmTokenCubit();
    languageState = LanguageLoaded(languages: const [], selectedId: '1');

    when(
      () => dashboardCubit.getDashboard(trend: any(named: 'trend')),
    ).thenAnswer((_) async {});
    when(() => orderCubit.loadOrders()).thenAnswer((_) async {});
    when(
      () => ecommerceCubit.loadOrders(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});
    when(() => returnCubit.loadOrders()).thenAnswer((_) async {});
    // The orders tab keeps its app bar while offline, and that bar reads the
    // filter state off all three list cubits — an unstubbed getter returns
    // null into a bool and the whole tab fails to build.
    for (final stub in [
      () => orderCubit.selectedStatus,
      () => ecommerceCubit.selectedStatus,
      () => returnCubit.selectedStatus,
    ]) {
      when(stub).thenReturn('');
    }
    for (final stub in [
      () => orderCubit.hasActiveFilters,
      () => ecommerceCubit.hasActiveFilters,
      () => returnCubit.hasActiveFilters,
    ]) {
      when(stub).thenReturn(false);
    }
    when(() => orderCubit.startDate).thenReturn(null);
    when(() => orderCubit.endDate).thenReturn(null);
    when(
      () => statusFilterCubit.orderStatusesFilter(
        channel: any(named: 'channel'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => returnStatusFilterCubit.returnOrderStatusesFilter(),
    ).thenAnswer((_) async {});
    when(() => settingsCubit.loadSettings()).thenAnswer((_) async {});
    when(() => statusCubit.checkStatus()).thenAnswer((_) async {});
    when(
      () => countrySettingsCubit.loadCountrySettings(force: any(named: 'force')),
    ).thenAnswer((_) async {});
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
    when(() => profileDetailCubit.loadProfile()).thenAnswer((_) async {});
    when(
      () => addFcmTokenCubit.addFcmToken(
        fcmToken: any(named: 'fcmToken'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async {});

    whenListen(
      dashboardCubit,
      const Stream<DashboardState>.empty(),
      initialState: DashboardInitial(),
    );
    whenListen(
      orderCubit,
      const Stream<PaginationState<OrderData>>.empty(),
      initialState: const PaginationInitial<OrderData>(),
    );
    whenListen(
      ecommerceCubit,
      const Stream<PaginationState<EcommerceOrderDataModel>>.empty(),
      initialState: const PaginationInitial<EcommerceOrderDataModel>(),
    );
    whenListen(
      returnCubit,
      const Stream<PaginationState<ReturnRequestData>>.empty(),
      initialState: const PaginationInitial<ReturnRequestData>(),
    );
    whenListen(
      statusFilterCubit,
      const Stream<OrderStatusListFilterState>.empty(),
      initialState: const AsyncInitial<List<OrderStatusData>>(),
    );
    whenListen(
      returnStatusFilterCubit,
      const Stream<ReturnOrderStatusListFilterState>.empty(),
      initialState: const AsyncInitial<List<OrderStatusData>>(),
    );
    whenListen(
      settingsCubit,
      const Stream<SettingsState>.empty(),
      initialState: SettingsInitial(),
    );
    whenListen(
      statusCubit,
      const Stream<DeliveryBoyStatusState>.empty(),
      initialState: DeliveryBoyStatusInitial(),
    );
    whenListen(
      countrySettingsCubit,
      const Stream<CountrySettingsState>.empty(),
      initialState: CountrySettingsInitial(),
    );
    whenListen(
      profileDetailCubit,
      const Stream<ProfileDetailState>.empty(),
      initialState: const ProfileDetailInitial(),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityDisconnected(),
    );
    whenListen(
      addFcmTokenCubit,
      const Stream<AddFcmTokenState>.empty(),
      initialState: const AsyncInitial<()>(),
    );
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  Future<void> pumpMain(
    WidgetTester tester, {
    Stream<LanguageState>? languageStream,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      languageCubit,
      languageStream ?? const Stream<LanguageState>.empty(),
      initialState: languageState,
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
          BlocProvider<OrderCubit>.value(value: orderCubit),
          BlocProvider<EcommerceOrderCubit>.value(value: ecommerceCubit),
          BlocProvider<ReturnOrderCubit>.value(value: returnCubit),
          BlocProvider<OrderStatusListFilterCubit>.value(
            value: statusFilterCubit,
          ),
          BlocProvider<ReturnOrderStatusListFilterCubit>.value(
            value: returnStatusFilterCubit,
          ),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<DeliveryBoyStatusCubit>.value(value: statusCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
          BlocProvider<ProfileDetailCubit>.value(value: profileDetailCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<LanguageCubit>.value(value: languageCubit),
          BlocProvider<AddFcmTokenCubit>.value(value: addFcmTokenCubit),
        ],
        // MainScreen builds its own AppScaffold.
        child: pumpTestWidget(const MainScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  IndexedStack stackOf(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack).first);

  testWidgets('renders the four tabs, starting on home', (tester) async {
    printTestDivider('MainScreen renders the four tabs, starting on home');
    await pumpMain(tester);

    printTestLog(
      'bottom bar → expected: 1, actual: ${find.byType(BottomNavBar).evaluate().length}',
    );
    expect(find.byType(BottomNavBar), findsOneWidget);
    final bar = tester.widget<BottomNavBar>(find.byType(BottomNavBar));
    printTestLog(
      'tabs → expected: [home, my_delivery, earnings, profile], '
      'actual: ${bar.items.map((i) => i.label)}',
    );
    expect(bar.items.map((i) => i.label).toList(), [
      LanguageLabelKeys.home,
      LanguageLabelKeys.myDelivery,
      LanguageLabelKeys.earnings,
      LanguageLabelKeys.profile,
    ]);
    printTestLog('index → expected: 0, actual: ${stackOf(tester).index}');
    expect(stackOf(tester).index, 0);
  });

  testWidgets('tapping a tab switches the stack to it', (tester) async {
    printTestDivider('MainScreen tapping a tab switches the stack to it');
    await pumpMain(tester);

    await tester.tap(find.text(LanguageLabelKeys.profile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('index → expected: 3, actual: ${stackOf(tester).index}');
    expect(stackOf(tester).index, 3);
    printTestLog(
      'bar currentIndex → expected: 3, '
      'actual: ${tester.widget<BottomNavBar>(find.byType(BottomNavBar)).currentIndex}',
    );
    expect(
      tester.widget<BottomNavBar>(find.byType(BottomNavBar)).currentIndex,
      3,
    );
  });

  testWidgets('every tab keeps its own state — the stack is indexed, not swapped', (
    tester,
  ) async {
    printTestDivider('MainScreen the stack keeps all four tabs mounted');
    await pumpMain(tester);

    printTestLog(
      'stack children → expected: 4, actual: ${stackOf(tester).children.length}',
    );
    expect(stackOf(tester).children.length, 4);
  });

  testWidgets('back is allowed on the home tab', (tester) async {
    printTestDivider('MainScreen back is allowed on the home tab');
    await pumpMain(tester);

    // MainScreen's PopScope infers as PopScope<Object>; a bare
    // find.byType(PopScope) means PopScope<dynamic> and silently matches
    // nothing (same trap as RadioListTile in the wallet suite).
    final popScope = tester.widget<PopScope<Object>>(_popScopeFinder);
    printTestLog('canPop → expected: true, actual: ${popScope.canPop}');
    expect(popScope.canPop, isTrue);
  });

  testWidgets('back on any other tab returns to home instead of leaving', (
    tester,
  ) async {
    printTestDivider('MainScreen back on another tab returns to home');
    await pumpMain(tester);

    await tester.tap(find.text(LanguageLabelKeys.earnings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final popScope = tester.widget<PopScope<Object>>(_popScopeFinder);
    printTestLog('canPop → expected: false, actual: ${popScope.canPop}');
    expect(popScope.canPop, isFalse);

    // didPop false = the framework blocked the pop and handed it back.
    popScope.onPopInvokedWithResult!(false, null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('index → expected: 0, actual: ${stackOf(tester).index}');
    expect(stackOf(tester).index, 0);
  });

  testWidgets('changing the language reloads the dashboard and every order list', (
    tester,
  ) async {
    printTestDivider('MainScreen a language change reloads dashboard + orders');
    final languageStream = Stream<LanguageState>.value(
      LanguageLoaded(languages: const [], selectedId: '2'),
    );
    await pumpMain(tester, languageStream: languageStream);
    await tester.pump();

    // Twice each: once from the tab's own initState, once from the reload.
    // `trend` defaults to '7', which is also what HomeScreen passes
    // explicitly, so both dashboard calls match the same verification.
    verify(() => dashboardCubit.getDashboard()).called(2);
    verify(() => orderCubit.loadOrders()).called(2);
    verify(() => ecommerceCubit.loadOrders()).called(2);
    verify(() => returnCubit.loadOrders()).called(2);
    printTestLog('reload on language change → verified');
  });

  testWidgets('re-emitting the same language reloads nothing', (tester) async {
    printTestDivider('MainScreen re-emitting the same language reloads nothing');
    final languageStream = Stream<LanguageState>.value(
      LanguageLoaded(languages: const [], selectedId: '1'),
    );
    await pumpMain(tester, languageStream: languageStream);
    await tester.pump();

    // Once each — the tabs' own initState calls, and nothing more: listenWhen
    // filters out an emission that keeps the same selectedId.
    verify(() => dashboardCubit.getDashboard()).called(1);
    verify(() => orderCubit.loadOrders()).called(1);
    verify(() => ecommerceCubit.loadOrders()).called(1);
    verify(() => returnCubit.loadOrders()).called(1);
    printTestLog('no reload on an unchanged language → verified');
  });

  testWidgets('registers the FCM token when login left it blank', (
    tester,
  ) async {
    printTestDivider('MainScreen registers the FCM token when login left it blank');
    await pumpMain(tester);
    // getToken() is a real async call into the fake messaging platform.
    await tester.pump();
    await tester.pump();

    verify(
      () => addFcmTokenCubit.addFcmToken(
        fcmToken: 'test-fcm-token',
        platform: Platform.isAndroid
            ? ApiParameters.android
            : ApiParameters.ios,
      ),
    ).called(1);
    printTestLog('addFcmToken → verified');
  });

  group('with a token already stored', () {
    // The put lives in setUp, not in the test body: a Hive write started
    // inside a testWidgets body never completes (the test's fake clock never
    // runs the event loop it finishes on) and then hangs tearDown's close().
    setUp(() => Hive.box(authBox).put(kFcmToken, 'already-registered'));

    testWidgets('does not re-register a token the session already has', (
      tester,
    ) async {
      printTestDivider('MainScreen does not re-register an existing token');
      await pumpMain(tester);
      await tester.pump();
      await tester.pump();

      verifyNever(
        () => addFcmTokenCubit.addFcmToken(
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
        ),
      );
      printTestLog('addFcmToken → expected: never called');
    });
  });
}
