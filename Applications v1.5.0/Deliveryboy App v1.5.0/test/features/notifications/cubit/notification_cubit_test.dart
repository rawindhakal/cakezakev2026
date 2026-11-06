import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/notifications/cubit/notification_cubit.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';

import '../../../helpers/mock_notification_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockNotificationRepository repository;

  setUp(() => repository = MockNotificationRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  final settings = AppNotificationSettings(
    status: 1,
    data: [AppNotificationSettingsData(category: 'Order Updates', events: [])],
  );

  blocTest<NotificationCubit, NotificationState>(
    'getNotificationSettings emits [Loading, Loaded] on success',
    setUp: () {
      printTestDivider(
        'NotificationCubit.getNotificationSettings emits [Loading, Loaded] on success',
      );
      when(
        () => repository.getNotificationSettings(),
      ).thenAnswer((_) async => settings);
    },
    build: () => NotificationCubit(repository: repository),
    act: (cubit) => cubit.getNotificationSettings(),
    expect: () => [isA<NotificationLoading>(), isA<NotificationLoaded>()],
    verify: (cubit) {
      final state = cubit.state as NotificationLoaded;
      printTestLog(
        'loaded.data → expected: same settings instance, actual matches: ${state.data == settings}',
      );
      expect(state.data, settings);
    },
  );

  blocTest<NotificationCubit, NotificationState>(
    'getNotificationSettings emits [Loading, Error] on ApiException',
    setUp: () {
      printTestDivider(
        'NotificationCubit.getNotificationSettings emits [Loading, Error] on ApiException',
      );
      when(() => repository.getNotificationSettings()).thenThrow(
        const ApiException(message: 'Notification settings unavailable'),
      );
    },
    build: () => NotificationCubit(repository: repository),
    act: (cubit) => cubit.getNotificationSettings(),
    expect: () => [isA<NotificationLoading>(), isA<NotificationError>()],
    verify: (cubit) {
      final state = cubit.state as NotificationError;
      printTestLog(
        'message → expected: "Notification settings unavailable", actual: "${state.message}"',
      );
      expect(state.message, 'Notification settings unavailable');
    },
  );
}
