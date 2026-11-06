import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/notifications/screens/notification_screen.dart';
import 'package:deliveryboy/features/notifications/widgets/notification_save_bar.dart';
import 'package:deliveryboy/features/notifications/widgets/notification_settings_skeleton_loader.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// NotificationScreen builds its own NotificationCubit/NotificationSaveCubit
/// internally (MultiBlocProvider inside the widget), so a mock cubit can't
/// be injected — the real cubits/repository run through the ApiClient
/// adapter seam instead, same approach as withdrawal_sheet_test.dart /
/// earnings_screen_test.dart. Only ConnectivityCubit is read from outside
/// (via context.read), so that one is still mocked normally.
void main() {
  late FakeApiAdapter adapter;
  late MockConnectivityCubit connectivityCubit;
  late Map<String, dynamic> settingsResponse;

  setUpAll(() {
    settingsResponse =
        jsonDecode(
              File(
                'test/fixtures/notifications/notification_settings.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.notificationPreferences: (options) {
        if (options.method == 'POST') {
          return {'status': 1, 'message': 'Settings saved'};
        }
        return settingsResponse;
      },
    });
    ApiClient().httpClientAdapter = adapter;

    connectivityCubit = MockConnectivityCubit();
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityConnected(),
    );
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> waitForResponse(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    ConnectivityState? connectivity,
    Stream<ConnectivityState>? connectivityStream,
    Size viewport = const Size(500, 1400),
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      connectivityCubit,
      connectivityStream ?? const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      BlocProvider<ConnectivityCubit>.value(
        value: connectivityCubit,
        // NotificationScreen builds its own AppScaffold.
        child: pumpTestWidget(const NotificationScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('fetches settings on first build and shows the skeleton', (
    tester,
  ) async {
    printTestDivider('fetches settings on first build and shows the skeleton');
    await pumpScreen(tester);

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(NotificationSettingsSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(NotificationSettingsSkeletonLoader), findsOneWidget);

    await waitForResponse(tester);
    printTestLog(
      'request → expected: contains ${ApiEndpoints.notificationPreferences}, actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, contains(ApiEndpoints.notificationPreferences));
  });

  testWidgets('shows an error state with retry when the fetch fails', (
    tester,
  ) async {
    printTestDivider('shows an error state with retry when the fetch fails');
    adapter = FakeApiAdapter({
      ApiEndpoints.notificationPreferences: (_) =>
          {'status': 0, 'message': 'Notification settings unavailable'},
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await waitForResponse(tester);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Notification settings unavailable" visible');
    expect(find.text('Notification settings unavailable'), findsOneWidget);

    final requestsBefore = adapter.requestedPaths.length;
    final emptyState = tester.widget<EmptyStateWidget>(find.byType(EmptyStateWidget));
    emptyState.onRetry!();
    await waitForResponse(tester);

    printTestLog(
      'retry → expected: another request, before: $requestsBefore, after: ${adapter.requestedPaths.length}',
    );
    expect(adapter.requestedPaths.length, greaterThan(requestsBefore));
  });

  testWidgets('shows an empty state when loaded with no categories', (
    tester,
  ) async {
    printTestDivider('shows an empty state when loaded with no categories');
    adapter = FakeApiAdapter({
      ApiEndpoints.notificationPreferences: (_) =>
          {'status': 1, 'message': 'ok', 'total': 0, 'data': <dynamic>[]},
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await waitForResponse(tester);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'save bar → expected: hidden, actual: ${find.byType(NotificationSaveBar).evaluate().length}',
    );
    // NotificationSaveBar is still mounted (bottomNavigationBar isn't
    // offline), but internally renders SizedBox.shrink for an empty list.
    expect(find.text(LanguageLabelKeys.saveSettings), findsNothing);
  });

  testWidgets('loaded with data renders the 3-tab TabBarView', (tester) async {
    printTestDivider('loaded with data renders the 3-tab TabBarView');
    await pumpScreen(tester);
    await waitForResponse(tester);

    printTestLog(
      'TabBarView → expected: 1, actual: ${find.byType(TabBarView).evaluate().length}',
    );
    expect(find.byType(TabBarView), findsOneWidget);
    printTestLog(
      'skeleton → expected: gone, actual: ${find.byType(NotificationSettingsSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(NotificationSettingsSkeletonLoader), findsNothing);

    // Email tab (first, default) — mail is non-null for every event in the
    // fixture, so all 3 categories and all 6 tiles show.
    printTestLog(
      'email tab switches → expected: 6, actual: ${find.byType(Switch).evaluate().length}',
    );
    expect(find.byType(Switch), findsNWidgets(6));
    expect(find.text('Order Updates'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Promotions'), findsOneWidget);
  });

  testWidgets(
    'the SMS tab hides a category whose events are all null for sms (including its header)',
    (tester) async {
      printTestDivider(
        'the SMS tab hides a category whose events are all null for sms (including its header)',
      );
      await pumpScreen(tester);
      await waitForResponse(tester);

      // Tap the 3rd tab (sms) in the app bar's bottom tab strip.
      await tester.tap(find.text(LanguageLabelKeys.sms));
      await tester.pumpAndSettle();

      // Payments and Promotions have sms:null on every event → both
      // categories (header included) render nothing on this tab. Only
      // Order Updates (sms: false, true) survives.
      printTestLog('Order Updates header → expected: visible');
      expect(find.text('Order Updates'), findsOneWidget);
      printTestLog('Payments header → expected: hidden (all-null sms)');
      expect(find.text('Payments'), findsNothing);
      printTestLog('Promotions header → expected: hidden (all-null sms)');
      expect(find.text('Promotions'), findsNothing);
      printTestLog(
        'sms tab switches → expected: 2, actual: ${find.byType(Switch).evaluate().length}',
      );
      expect(find.byType(Switch), findsNWidgets(2));
    },
  );

  testWidgets('toggling a switch mutates the model in place, no cubit call until Save', (
    tester,
  ) async {
    printTestDivider(
      'toggling a switch mutates the model in place, no cubit call until Save',
    );
    await pumpScreen(tester);
    await waitForResponse(tester);

    // Email tab, first switch (order_placed, mail: true) → flip to false,
    // then Save and inspect what actually got POSTed.
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text(LanguageLabelKeys.saveSettings),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(LanguageLabelKeys.saveSettings));
    await tester.pump();
    await waitForResponse(tester);

    // The save POST is the only recorded request carrying a body — the GET
    // refetch that follows a successful save has none — so pick it out
    // that way rather than assuming request order.
    final saveRequest = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.notificationPreferences && r.data is Map,
    );
    final body = saveRequest.data as Map;
    final preferences = body['preferences'] as List;
    final orderPlaced = preferences.firstWhere((p) => p['key'] == 'order_placed')
        as Map;
    final channels = orderPlaced['channels'] as Map;
    printTestLog(
      'order_placed.channels.mail after toggle → expected: false, actual: ${channels['mail']}',
    );
    expect(channels['mail'], isFalse);
  });

  testWidgets('a successful save shows a snackbar and refetches the list', (
    tester,
  ) async {
    printTestDivider('a successful save shows a snackbar and refetches the list');
    await pumpScreen(tester);
    await waitForResponse(tester);

    final getsBefore = adapter.requests
        .where((r) => r.path == ApiEndpoints.notificationPreferences)
        .length;

    await tester.tap(find.text(LanguageLabelKeys.saveSettings));
    await tester.pump();
    await waitForResponse(tester);

    printTestLog(
      'success message → expected: "${LanguageLabelKeys.settingsSaved}" visible',
    );
    expect(find.text(LanguageLabelKeys.settingsSaved), findsOneWidget);

    final requestsAfter = adapter.requests
        .where((r) => r.path == ApiEndpoints.notificationPreferences)
        .length;
    printTestLog(
      'requests → expected: more than $getsBefore (save + refetch), actual: $requestsAfter',
    );
    expect(requestsAfter, greaterThan(getsBefore));
  });

  testWidgets('a rejected save surfaces the server error and does not refetch', (
    tester,
  ) async {
    printTestDivider('a rejected save surfaces the server error and does not refetch');
    adapter = FakeApiAdapter({
      ApiEndpoints.notificationPreferences: (options) {
        if (options.method == 'POST') {
          return {'status': 0, 'message': 'Could not save preferences'};
        }
        return settingsResponse;
      },
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpScreen(tester);
    await waitForResponse(tester);

    final requestsBefore = adapter.requestedPaths.length;

    await tester.tap(find.text(LanguageLabelKeys.saveSettings));
    await tester.pump();
    await waitForResponse(tester);

    printTestLog('error message → expected: "Could not save preferences" visible');
    expect(find.text('Could not save preferences'), findsOneWidget);

    // Only the save POST fired — no follow-up GET refetch on error.
    printTestLog(
      'requests → expected: exactly 1 more (the failed POST), before: $requestsBefore, after: ${adapter.requestedPaths.length}',
    );
    expect(adapter.requestedPaths.length, requestsBefore + 1);
  });

  testWidgets('replaces the body with the offline screen and hides tabs/save bar', (
    tester,
  ) async {
    printTestDivider(
      'replaces the body with the offline screen and hides tabs/save bar',
    );
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());
    await waitForResponse(tester);

    printTestLog(
      'offline screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog(
      'tab bar → expected: hidden, actual: ${find.text(LanguageLabelKeys.sms).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.sms), findsNothing);
    printTestLog(
      'save bar → expected: hidden, actual: ${find.text(LanguageLabelKeys.saveSettings).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.saveSettings), findsNothing);

    final requestsBefore = adapter.requestedPaths.length;
    final offlineScreen = tester.widget<AppNoInternetFullScreen>(
      find.byType(AppNoInternetFullScreen),
    );
    offlineScreen.onRetry!();
    await waitForResponse(tester);

    printTestLog(
      'offline retry → expected: another request, before: $requestsBefore, after: ${adapter.requestedPaths.length}',
    );
    expect(adapter.requestedPaths.length, greaterThan(requestsBefore));
  });

  testWidgets('reconnecting refetches the list', (tester) async {
    printTestDivider('reconnecting refetches the list');
    final controller = StreamController<ConnectivityState>();
    addTearDown(controller.close);

    await pumpScreen(
      tester,
      connectivity: ConnectivityConnected(),
      connectivityStream: controller.stream,
    );
    await waitForResponse(tester);
    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.notificationPreferences)
        .length;

    controller.add(ConnectivityConnected());
    await tester.pump();
    await waitForResponse(tester);

    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.notificationPreferences)
        .length;
    printTestLog('requests → before: $before, after reconnect: $after');
    expect(after, greaterThan(before));
  });
}
