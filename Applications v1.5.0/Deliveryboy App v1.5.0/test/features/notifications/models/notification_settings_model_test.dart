import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/notifications/notification_settings.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('Channels.fromJson', () {
    test('parses every field, lenient bool per toSafeBoolOrNull', () {
      printTestDivider(
        'Channels.fromJson parses every field, lenient bool per toSafeBoolOrNull',
      );
      final channels = Channels.fromJson({
        'mail': true,
        'push': 0,
        'sms': 'true',
      });

      printTestLog('mail → expected: true, actual: ${channels.mail}');
      expect(channels.mail, isTrue);
      printTestLog('push → expected: false (num 0), actual: ${channels.push}');
      expect(channels.push, isFalse);
      printTestLog('sms → expected: true (string "true"), actual: ${channels.sms}');
      expect(channels.sms, isTrue);
    });

    test('a missing/null field stays null — channel not applicable', () {
      printTestDivider(
        'Channels.fromJson a missing/null field stays null — channel not applicable',
      );
      final channels = Channels.fromJson({'mail': true, 'push': true});

      printTestLog('sms → expected: null, actual: ${channels.sms}');
      expect(channels.sms, isNull);
    });

    test('an unparsable value falls back to null', () {
      printTestDivider('Channels.fromJson an unparsable value falls back to null');
      final channels = Channels.fromJson({'mail': 'not-a-bool'});

      printTestLog('mail → expected: null, actual: ${channels.mail}');
      expect(channels.mail, isNull);
    });
  });

  group('Channels.toJson', () {
    test('omits a null channel field instead of writing null', () {
      printTestDivider(
        'Channels.toJson omits a null channel field instead of writing null',
      );
      final channels = Channels(mail: true, push: false, sms: null);

      final json = channels.toJson();
      printTestLog('json keys → expected: [mail, push] (no sms), actual: ${json.keys}');
      expect(json.containsKey('sms'), isFalse);
      expect(json['mail'], isTrue);
      expect(json['push'], isFalse);
    });
  });

  group('Events.fromJson / toJson', () {
    test('parses key/label/channels from a real event', () {
      printTestDivider('Events.fromJson parses key/label/channels from a real event');
      final row =
          ((fixture()['data'] as List).first
                  as Map<String, dynamic>)['events']
              as List;
      final event = Events.fromJson(row.first as Map<String, dynamic>);

      printTestLog('key → expected: "order_placed", actual: "${event.key}"');
      expect(event.key, 'order_placed');
      printTestLog('label → expected: "Order Placed", actual: "${event.label}"');
      expect(event.label, 'Order Placed');
      printTestLog('channels.mail → expected: true, actual: ${event.channels?.mail}');
      expect(event.channels?.mail, isTrue);
      printTestLog('channels.sms → expected: false, actual: ${event.channels?.sms}');
      expect(event.channels?.sms, isFalse);
    });

    test('missing channels stays null, not a default Channels()', () {
      printTestDivider(
        'Events.fromJson missing channels stays null, not a default Channels()',
      );
      final event = Events.fromJson({'key': 'k', 'label': 'l'});

      printTestLog('channels → expected: null, actual: ${event.channels}');
      expect(event.channels, isNull);
    });

    test('round-trips through toJson', () {
      printTestDivider('Events.toJson round-trips through fromJson');
      final event = Events(
        key: 'order_placed',
        label: 'Order Placed',
        channels: Channels(mail: true, push: false, sms: null),
      );

      final roundTripped = Events.fromJson(event.toJson());
      printTestLog('key → expected: "${event.key}", actual: "${roundTripped.key}"');
      expect(roundTripped.key, event.key);
      printTestLog(
        'channels.mail → expected: ${event.channels?.mail}, actual: ${roundTripped.channels?.mail}',
      );
      expect(roundTripped.channels?.mail, event.channels?.mail);
      printTestLog(
        'channels.sms → expected: null, actual: ${roundTripped.channels?.sms}',
      );
      expect(roundTripped.channels?.sms, isNull);
    });
  });

  group('AppNotificationSettingsData.fromJson / toJson', () {
    test('parses category and its events list', () {
      printTestDivider(
        'AppNotificationSettingsData.fromJson parses category and its events list',
      );
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final data = AppNotificationSettingsData.fromJson(row);

      printTestLog('category → expected: "Order Updates", actual: "${data.category}"');
      expect(data.category, 'Order Updates');
      printTestLog('events.length → expected: 2, actual: ${data.events?.length}');
      expect(data.events?.length, 2);
    });

    test('a missing events key stays null, not an empty list', () {
      printTestDivider(
        'AppNotificationSettingsData.fromJson a missing events key stays null, not an empty list',
      );
      final data = AppNotificationSettingsData.fromJson({'category': 'X'});

      printTestLog('events → expected: null, actual: ${data.events}');
      expect(data.events, isNull);
    });

    test('round-trips through toJson', () {
      printTestDivider('AppNotificationSettingsData.toJson round-trips through fromJson');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final data = AppNotificationSettingsData.fromJson(row);

      final roundTripped = AppNotificationSettingsData.fromJson(data.toJson());
      printTestLog(
        'category → expected: "${data.category}", actual: "${roundTripped.category}"',
      );
      expect(roundTripped.category, data.category);
      printTestLog(
        'events.length → expected: ${data.events?.length}, actual: ${roundTripped.events?.length}',
      );
      expect(roundTripped.events?.length, data.events?.length);
    });
  });

  group('AppNotificationSettings.fromJson', () {
    test('parses status/message/total and 3 categories from a full payload', () {
      printTestDivider(
        'AppNotificationSettings.fromJson parses status/message/total and 3 categories from a full payload',
      );
      final settings = AppNotificationSettings.fromJson(fixture());

      printTestLog('status → expected: 1, actual: ${settings.status}');
      expect(settings.status, 1);
      printTestLog(
        'message → expected: "Notification preferences fetched successfully", actual: "${settings.message}"',
      );
      expect(settings.message, 'Notification preferences fetched successfully');
      printTestLog('total → expected: 3, actual: ${settings.total}');
      expect(settings.total, 3);
      printTestLog('data.length → expected: 3, actual: ${settings.data?.length}');
      expect(settings.data?.length, 3);
      printTestLog(
        'data[2].category → expected: "Promotions", actual: "${settings.data?[2].category}"',
      );
      expect(settings.data?[2].category, 'Promotions');
    });

    test('status/total lenient-parse a quoted numeric string', () {
      printTestDivider(
        'AppNotificationSettings.fromJson status/total lenient-parse a quoted numeric string',
      );
      final settings = AppNotificationSettings.fromJson({
        'status': '1',
        'total': '3',
      });

      printTestLog('status → expected: 1, actual: ${settings.status}');
      expect(settings.status, 1);
      printTestLog('total → expected: 3, actual: ${settings.total}');
      expect(settings.total, 3);
    });

    test('a missing/null data key stays null, not an empty list', () {
      printTestDivider(
        'AppNotificationSettings.fromJson a missing/null data key stays null, not an empty list',
      );
      final missing = AppNotificationSettings.fromJson({'status': 1});
      final explicitNull = AppNotificationSettings.fromJson({
        'status': 1,
        'data': null,
      });

      printTestLog('data (missing key) → expected: null, actual: ${missing.data}');
      expect(missing.data, isNull);
      printTestLog(
        'data (explicit null) → expected: null, actual: ${explicitNull.data}',
      );
      expect(explicitNull.data, isNull);
    });

    test('missing/null fields do not crash', () {
      printTestDivider('AppNotificationSettings.fromJson missing/null fields do not crash');
      final settings = AppNotificationSettings.fromJson(const {});

      printTestLog('status → expected: null, actual: ${settings.status}');
      expect(settings.status, isNull);
      printTestLog('message → expected: null, actual: ${settings.message}');
      expect(settings.message, isNull);
      printTestLog('data → expected: null, actual: ${settings.data}');
      expect(settings.data, isNull);
    });
  });

  group('AppNotificationSettings.toJson', () {
    test('round-trips a full payload at all 4 levels', () {
      printTestDivider(
        'AppNotificationSettings.toJson round-trips a full payload at all 4 levels',
      );
      final settings = AppNotificationSettings.fromJson(fixture());

      final roundTripped = AppNotificationSettings.fromJson(settings.toJson());
      printTestLog('status → expected: ${settings.status}, actual: ${roundTripped.status}');
      expect(roundTripped.status, settings.status);
      printTestLog(
        'data.length → expected: ${settings.data?.length}, actual: ${roundTripped.data?.length}',
      );
      expect(roundTripped.data?.length, settings.data?.length);
      printTestLog(
        'data[1].events[1].key → expected: "${settings.data?[1].events?[1].key}", actual: "${roundTripped.data?[1].events?[1].key}"',
      );
      expect(
        roundTripped.data?[1].events?[1].key,
        settings.data?[1].events?[1].key,
      );
      printTestLog(
        'data[1].events[1].channels.sms → expected: null, actual: ${roundTripped.data?[1].events?[1].channels?.sms}',
      );
      expect(roundTripped.data?[1].events?[1].channels?.sms, isNull);
    });
  });
}
