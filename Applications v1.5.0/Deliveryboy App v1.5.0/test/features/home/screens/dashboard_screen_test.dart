import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/cubit/dashboard_cubit.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';
import 'package:deliveryboy/features/home/screens/dashboard_screen.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_skeleton_loader.dart';
import 'package:deliveryboy/features/home/widgets/home_header.dart';
import 'package:deliveryboy/features/home/widgets/home_overview_section.dart';
import 'package:deliveryboy/features/home/widgets/home_performance_section.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/firebase_test_helper.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockDashboardCubit dashboardCubit;
  late MockDeliveryBoyStatusCubit statusCubit;
  late MockSettingsCubit settingsCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late MockProfileDetailCubit profileDetailCubit;
  late MockConnectivityCubit connectivityCubit;
  late DashboardModel dashboard;

  setUpAll(() async {
    // HomeScreen's initState reaches NotificationService.instance, which
    // builds FirebaseMessaging.instance in a field initializer.
    await FirebaseTestHelper.setUp();
    dashboard = DashboardModel.fromJson(
      jsonDecode(
            File('test/fixtures/home/dashboard_response.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
  });

  tearDownAll(() {
    FirebaseTestHelper.tearDown();
    printTestDivider('=== All tests run! ===');
  });

  // The header reads the rider's name/email/avatar straight from AuthHiveBox,
  // and HomePerformanceSection formats today's date through AppDateFormatter,
  // which reads SettingsHiveBox — so both boxes have to be open.
  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);
    await Hive.box(authBox).putAll({
      kUserName: 'Alex Johnson',
      kUserEmail: 'alex@gmail.com',
      kUserProfile: '',
    });

    dashboardCubit = MockDashboardCubit();
    statusCubit = MockDeliveryBoyStatusCubit();
    settingsCubit = MockSettingsCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    profileDetailCubit = MockProfileDetailCubit();
    connectivityCubit = MockConnectivityCubit();

    when(
      () => dashboardCubit.getDashboard(trend: any(named: 'trend')),
    ).thenAnswer((_) async {});
    when(() => statusCubit.checkStatus()).thenAnswer((_) async {});
    when(() => settingsCubit.loadSettings()).thenAnswer((_) async {});
    when(
      () => countrySettingsCubit.loadCountrySettings(
        force: any(named: 'force'),
      ),
    ).thenAnswer((_) async {});
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
    when(() => profileDetailCubit.loadProfile()).thenAnswer((_) async {});

    whenListen(
      settingsCubit,
      const Stream<SettingsState>.empty(),
      initialState: SettingsInitial(),
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
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required DashboardState dashboardState,
    DeliveryBoyStatusState? statusState,
    ConnectivityState? connectivity,
    Stream<DeliveryBoyStatusState>? statusStream,
    Size viewport = const Size(500, 2400),
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      dashboardCubit,
      const Stream<DashboardState>.empty(),
      initialState: dashboardState,
    );
    whenListen(
      statusCubit,
      statusStream ?? const Stream<DeliveryBoyStatusState>.empty(),
      initialState:
          statusState ?? const DeliveryBoyStatusLoaded((status: 1, remark: null)),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
          BlocProvider<DeliveryBoyStatusCubit>.value(value: statusCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
          BlocProvider<ProfileDetailCubit>.value(value: profileDetailCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // HomeScreen builds its own AppScaffold.
        child: pumpTestWidget(const HomeScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('fetches everything it needs on first build', (tester) async {
    printTestDivider('fetches everything it needs on first build');
    await pumpScreen(tester, dashboardState: const DashboardLoading());

    // The default trend window is the last 7 days.
    verify(() => dashboardCubit.getDashboard(trend: '7')).called(1);
    verify(() => statusCubit.checkStatus()).called(1);
    verify(() => settingsCubit.loadSettings()).called(1);
    verify(() => profileDetailCubit.loadProfile()).called(1);
    printTestLog('initial fetches → all verified');
  });

  testWidgets('shows the skeleton while the dashboard is loading', (
    tester,
  ) async {
    printTestDivider('shows the skeleton while the dashboard is loading');
    await pumpScreen(tester, dashboardState: const DashboardLoading());

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(DashboardSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(DashboardSkeletonLoader), findsOneWidget);
    printTestLog(
      'overview → expected: absent, actual: ${find.byType(HomeOverviewSection).evaluate().length}',
    );
    expect(find.byType(HomeOverviewSection), findsNothing);
  });

  testWidgets('shows the skeleton before the first fetch resolves too', (
    tester,
  ) async {
    printTestDivider('shows the skeleton before the first fetch resolves too');
    await pumpScreen(tester, dashboardState: const DashboardInitial());

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(DashboardSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(DashboardSkeletonLoader), findsOneWidget);
  });

  testWidgets('renders both dashboard sections once loaded', (tester) async {
    printTestDivider('renders both dashboard sections once loaded');
    await pumpScreen(tester, dashboardState: DashboardLoaded(dashboard));

    printTestLog(
      'performance section → expected: 1, actual: ${find.byType(HomePerformanceSection).evaluate().length}',
    );
    expect(find.byType(HomePerformanceSection), findsOneWidget);
    printTestLog(
      'overview section → expected: 1, actual: ${find.byType(HomeOverviewSection).evaluate().length}',
    );
    expect(find.byType(HomeOverviewSection), findsOneWidget);
    printTestLog(
      'skeleton → expected: absent, actual: ${find.byType(DashboardSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(DashboardSkeletonLoader), findsNothing);
  });

  testWidgets('shows the error message with a retry when the fetch fails', (
    tester,
  ) async {
    printTestDivider('shows the error message with a retry when the fetch fails');
    await pumpScreen(
      tester,
      dashboardState: const DashboardError('Dashboard unavailable'),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('error text → expected: "Dashboard unavailable" visible');
    expect(find.text('Dashboard unavailable'), findsOneWidget);

    // Regression guard: this branch used to be built with
    // `SliverFillRemaining(hasScrollBody: false)`, which measured
    // EmptyStateWidget's intrinsic height. Its root is a LayoutBuilder, so
    // every failed fetch threw "LayoutBuilder does not support returning
    // intrinsic dimensions" followed by a null-check crash in the viewport.
    final error = tester.takeException();
    printTestLog('render exception → expected: none, actual: $error');
    expect(error, isNull);
  });

  testWidgets('keeps the header on screen in every dashboard state', (
    tester,
  ) async {
    printTestDivider('keeps the header on screen in every dashboard state');
    // The header sits outside the dashboard state switch so it stays put while
    // the content below swaps to the skeleton on every refetch.
    for (final state in <DashboardState>[
      const DashboardLoading(),
      DashboardLoaded(dashboard),
      const DashboardError('Dashboard unavailable'),
    ]) {
      await pumpScreen(tester, dashboardState: state);
      printTestLog(
        '${state.runtimeType} → header expected: 1, actual: ${find.byType(HomeHeader).evaluate().length}',
      );
      expect(find.byType(HomeHeader), findsOneWidget);
    }
  });

  testWidgets('replaces the dashboard with the offline screen when disconnected', (
    tester,
  ) async {
    printTestDivider(
      'replaces the dashboard with the offline screen when disconnected',
    );
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      connectivity: ConnectivityDisconnected(),
    );

    printTestLog(
      'no-internet screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog('header → expected: absent, actual: ${find.byType(HomeHeader).evaluate().length}');
    expect(find.byType(HomeHeader), findsNothing);
  });

  testWidgets('shows the rider as online when the status is 1', (tester) async {
    printTestDivider('shows the rider as online when the status is 1');
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      statusState: const DeliveryBoyStatusLoaded((status: 1, remark: null)),
    );

    final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
    printTestLog('isOnline (status 1) → expected: true, actual: ${header.isOnline}');
    expect(header.isOnline, isTrue);
  });

  testWidgets('shows the rider as offline for any status other than 1', (
    tester,
  ) async {
    printTestDivider('shows the rider as offline for any status other than 1');
    // A separate test rather than a second pumpScreen in the one above:
    // re-stubbing the mock and pumping the same widget again does not rebuild
    // it, so the header would still report the first status.
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      statusState: const DeliveryBoyStatusLoaded((status: 3, remark: null)),
    );

    final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
    printTestLog('isOnline (status 3) → expected: false, actual: ${header.isOnline}');
    expect(header.isOnline, isFalse);
  });

  testWidgets('tapping the header toggle opens the confirm dialog', (
    tester,
  ) async {
    printTestDivider('tapping the header toggle opens the confirm dialog');
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      statusState: const DeliveryBoyStatusLoaded((status: 1, remark: null)),
    );

    tester.widget<HomeHeader>(find.byType(HomeHeader)).onToggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog(
      'dialog → expected: 1, actual: ${find.byType(AppConfirmDialog).evaluate().length}',
    );
    expect(find.byType(AppConfirmDialog), findsOneWidget);
    // Online rider toggling means they are going offline.
    printTestLog('copy → expected: "${LanguageLabelKeys.confirmGoOffline}" visible');
    expect(find.text(LanguageLabelKeys.confirmGoOffline), findsOneWidget);
  });

  testWidgets('raises the blocked dialog when the status comes back as 4', (
    tester,
  ) async {
    printTestDivider('raises the blocked dialog when the status comes back as 4');
    // The listener only fires on a state *change*, so the blocked status has
    // to arrive through the stream rather than as the initial state.
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      statusState: const DeliveryBoyStatusLoading(),
      statusStream: Stream<DeliveryBoyStatusState>.fromIterable([
        const DeliveryBoyStatusLoaded((status: 4, remark: 'Documents expired')),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog(
      'blocked dialog → expected: "${LanguageLabelKeys.accountBlocked}" visible',
    );
    expect(find.text(LanguageLabelKeys.accountBlocked), findsOneWidget);
    printTestLog('remark → expected: "Documents expired" visible');
    expect(find.text('Documents expired'), findsOneWidget);
  });

  testWidgets('does not raise the blocked dialog for an active rider', (
    tester,
  ) async {
    printTestDivider('does not raise the blocked dialog for an active rider');
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      statusState: const DeliveryBoyStatusLoading(),
      statusStream: Stream<DeliveryBoyStatusState>.fromIterable([
        const DeliveryBoyStatusLoaded((status: 1, remark: null)),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('blocked dialog → expected: absent');
    expect(find.text(LanguageLabelKeys.accountBlocked), findsNothing);
  });

  testWidgets('pulling down refetches the dashboard and the status', (
    tester,
  ) async {
    printTestDivider('pulling down refetches the dashboard and the status');
    // A short viewport on purpose: with the tall one the other tests use, the
    // whole dashboard fits and the scroll view never leaves its idle state, so
    // RefreshIndicator never arms and the pull is silently a no-op.
    await pumpScreen(
      tester,
      dashboardState: DashboardLoaded(dashboard),
      viewport: const Size(500, 700),
    );

    // One call each from initState; the pull adds a second. The gesture is
    // driven by hand rather than with drag()/fling(): RefreshIndicator only
    // arms itself while a drag is still in progress, so the pointer has to be
    // moved in steps and held past the trigger distance before being lifted.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => dashboardCubit.getDashboard(trend: '7')).called(2);
    verify(() => statusCubit.checkStatus()).called(2);
    // Refresh forces the country settings through, unlike the initial load.
    verify(() => countrySettingsCubit.loadCountrySettings(force: true)).called(1);
    printTestLog('refresh fetches → all verified');
  });
}
