import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';
import 'package:deliveryboy/features/notifications/repositories/notification_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late NotificationRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/notifications/notification_settings.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = NotificationRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('getNotificationSettings', () {
    test('hits notificationPreferences via GET and parses the response', () async {
      printTestDivider(
        'getNotificationSettings hits notificationPreferences via GET and parses the response',
      );
      when(
        () => mockApiClient.get(ApiEndpoints.notificationPreferences),
      ).thenAnswer((_) async => fixture());

      final settings = await repository.getNotificationSettings();

      verify(() => mockApiClient.get(ApiEndpoints.notificationPreferences)).called(1);
      printTestLog('data.length → expected: 3, actual: ${settings.data?.length}');
      expect(settings.data?.length, 3);
      printTestLog(
        'data[0].category → expected: "Order Updates", actual: "${settings.data?[0].category}"',
      );
      expect(settings.data?[0].category, 'Order Updates');
    });
  });

  group('saveNotificationSettings', () {
    test('POSTs preferences built from key/channels.toJson() per event', () async {
      printTestDivider(
        'saveNotificationSettings POSTs preferences built from key/channels.toJson() per event',
      );
      when(
        () => mockApiClient.post(
          ApiEndpoints.notificationPreferences,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => fixture());

      final preferences = [
        Events(
          key: 'order_placed',
          label: 'Order Placed',
          channels: Channels(mail: true, push: false, sms: null),
        ),
        Events(
          key: 'payment_received',
          label: 'Payment Received',
          channels: Channels(mail: false, push: true, sms: true),
        ),
      ];

      await repository.saveNotificationSettings(preferences: preferences);

      final captured = verify(
        () => mockApiClient.post(
          ApiEndpoints.notificationPreferences,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;

      final sentPreferences = captured[ApiParameters.preferences] as List;
      printTestLog('preferences.length → expected: 2, actual: ${sentPreferences.length}');
      expect(sentPreferences.length, 2);

      final first = sentPreferences[0] as Map<String, dynamic>;
      printTestLog(
        'preferences[0].key → expected: "order_placed", actual: "${first[ApiParameters.key]}"',
      );
      expect(first[ApiParameters.key], 'order_placed');
      final firstChannels = first[ApiParameters.channels] as Map<String, dynamic>;
      printTestLog(
        'preferences[0].channels → expected: {mail: true, push: false} (no sms), actual: $firstChannels',
      );
      expect(firstChannels['mail'], isTrue);
      expect(firstChannels['push'], isFalse);
      expect(firstChannels.containsKey('sms'), isFalse);

      final second = sentPreferences[1] as Map<String, dynamic>;
      printTestLog(
        'preferences[1].key → expected: "payment_received", actual: "${second[ApiParameters.key]}"',
      );
      expect(second[ApiParameters.key], 'payment_received');
    });

    test('returns the parsed response', () async {
      printTestDivider('saveNotificationSettings returns the parsed response');
      when(
        () => mockApiClient.post(
          ApiEndpoints.notificationPreferences,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => fixture());

      final settings = await repository.saveNotificationSettings(preferences: []);

      printTestLog('status → expected: 1, actual: ${settings.status}');
      expect(settings.status, 1);
    });
  });
}
