import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/loading_widget.dart';
import 'package:deliveryboy/features/notifications/cubit/notification_cubit.dart';
import 'package:deliveryboy/features/notifications/cubit/notification_save_cubit.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';
import 'package:deliveryboy/features/notifications/widgets/notification_save_bar.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockNotificationCubit cubit;
  late MockNotificationSaveCubit saveCubit;

  setUp(() {
    cubit = MockNotificationCubit();
    saveCubit = MockNotificationSaveCubit();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  AppNotificationSettings settingsWith(List<AppNotificationSettingsData> data) =>
      AppNotificationSettings(status: 1, data: data);

  Future<void> pumpBar(
    WidgetTester tester, {
    required NotificationState state,
    NotificationSaveState? saveState,
  }) async {
    whenListen(
      cubit,
      const Stream<NotificationState>.empty(),
      initialState: state,
    );
    whenListen(
      saveCubit,
      const Stream<NotificationSaveState>.empty(),
      initialState: saveState ?? const NotificationSaveInitial(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<NotificationCubit>.value(value: cubit),
          BlocProvider<NotificationSaveCubit>.value(value: saveCubit),
        ],
        child: pumpTestWidget(const NotificationSaveBar()),
      ),
    );
    await tester.pump();
  }

  testWidgets('hidden when NotificationCubit is not Loaded', (tester) async {
    printTestDivider('hidden when NotificationCubit is not Loaded');
    await pumpBar(tester, state: const NotificationLoading());

    printTestLog(
      'AppButton → expected: absent, actual: ${find.byType(AppButton).evaluate().length}',
    );
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('hidden when Loaded with an empty category list', (tester) async {
    printTestDivider('hidden when Loaded with an empty category list');
    await pumpBar(tester, state: NotificationLoaded(settingsWith([])));

    printTestLog(
      'AppButton → expected: absent, actual: ${find.byType(AppButton).evaluate().length}',
    );
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('visible when Loaded with categories', (tester) async {
    printTestDivider('visible when Loaded with categories');
    await pumpBar(
      tester,
      state: NotificationLoaded(
        settingsWith([
          AppNotificationSettingsData(category: 'Order Updates', events: [
            Events(key: 'order_placed', channels: Channels(mail: true)),
          ]),
        ]),
      ),
    );

    printTestLog(
      'AppButton → expected: 1, actual: ${find.byType(AppButton).evaluate().length}',
    );
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('tap flattens every category\'s events and calls saveNotificationSettings', (
    tester,
  ) async {
    printTestDivider(
      "tap flattens every category's events and calls saveNotificationSettings",
    );
    final eventA = Events(key: 'order_placed', channels: Channels(mail: true));
    final eventB = Events(key: 'payment_received', channels: Channels(mail: false));
    final eventC = Events(key: 'promo_offer', channels: Channels(mail: true));
    when(
      () => saveCubit.saveNotificationSettings(
        preferences: any(named: 'preferences'),
      ),
    ).thenAnswer((_) async {});

    await pumpBar(
      tester,
      state: NotificationLoaded(
        settingsWith([
          AppNotificationSettingsData(category: 'Order Updates', events: [eventA, eventB]),
          AppNotificationSettingsData(category: 'Promotions', events: [eventC]),
        ]),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    final captured = verify(
      () => saveCubit.saveNotificationSettings(
        preferences: captureAny(named: 'preferences'),
      ),
    ).captured.single as List<Events>;
    printTestLog(
      'flattened preferences → expected: [order_placed, payment_received, promo_offer], actual: ${captured.map((e) => e.key).toList()}',
    );
    expect(captured, [eventA, eventB, eventC]);
  });

  testWidgets('shows a spinner on the button while saving', (tester) async {
    printTestDivider('shows a spinner on the button while saving');
    await pumpBar(
      tester,
      state: NotificationLoaded(
        settingsWith([
          AppNotificationSettingsData(category: 'Order Updates', events: [
            Events(key: 'order_placed', channels: Channels(mail: true)),
          ]),
        ]),
      ),
      saveState: const NotificationSaveLoading(),
    );

    printTestLog(
      'loading indicator → expected: 1, actual: ${find.byType(LoadingWidget).evaluate().length}',
    );
    expect(find.byType(LoadingWidget), findsOneWidget);
  });
}
