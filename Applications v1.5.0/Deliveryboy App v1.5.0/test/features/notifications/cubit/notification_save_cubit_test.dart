import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/notifications/cubit/notification_save_cubit.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';

import '../../../helpers/mock_notification_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockNotificationRepository repository;

  setUp(() => repository = MockNotificationRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  final preferences = [
    Events(
      key: 'order_placed',
      label: 'Order Placed',
      channels: Channels(mail: true, push: false, sms: null),
    ),
  ];

  blocTest<NotificationSaveCubit, NotificationSaveState>(
    'saveNotificationSettings emits [Loading, Loaded] on success',
    setUp: () {
      printTestDivider(
        'NotificationSaveCubit.saveNotificationSettings emits [Loading, Loaded] on success',
      );
      when(
        () => repository.saveNotificationSettings(
          preferences: any(named: 'preferences'),
        ),
      ).thenAnswer((_) async => AppNotificationSettings(status: 1, data: []));
    },
    build: () => NotificationSaveCubit(repository: repository),
    act: (cubit) => cubit.saveNotificationSettings(preferences: preferences),
    expect: () => [
      isA<NotificationSaveLoading>(),
      isA<NotificationSaveLoaded>(),
    ],
    verify: (_) {
      final captured = verify(
        () => repository.saveNotificationSettings(
          preferences: captureAny(named: 'preferences'),
        ),
      ).captured.single as List<Events>;
      printTestLog(
        'preferences forwarded → expected: same list instance, actual: identical=${identical(captured, preferences)}',
      );
      expect(identical(captured, preferences), isTrue);
    },
  );

  blocTest<NotificationSaveCubit, NotificationSaveState>(
    'saveNotificationSettings emits [Loading, Error] on ApiException',
    setUp: () {
      printTestDivider(
        'NotificationSaveCubit.saveNotificationSettings emits [Loading, Error] on ApiException',
      );
      when(
        () => repository.saveNotificationSettings(
          preferences: any(named: 'preferences'),
        ),
      ).thenThrow(const ApiException(message: 'Could not save preferences'));
    },
    build: () => NotificationSaveCubit(repository: repository),
    act: (cubit) => cubit.saveNotificationSettings(preferences: preferences),
    expect: () => [
      isA<NotificationSaveLoading>(),
      isA<NotificationSaveError>(),
    ],
    verify: (cubit) {
      final state = cubit.state as NotificationSaveError;
      printTestLog(
        'message → expected: "Could not save preferences", actual: "${state.message}"',
      );
      expect(state.message, 'Could not save preferences');
    },
  );
}
