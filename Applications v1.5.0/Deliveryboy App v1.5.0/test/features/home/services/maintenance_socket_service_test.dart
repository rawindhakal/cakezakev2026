import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/features/home/services/maintenance_socket_service.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

/// Drives the real service against a local Pusher-protocol server rather than
/// mocking the socket: the service resolves its URL from cached settings, so
/// pointing `broadcast_config` at 127.0.0.1 exercises connect, subscribe,
/// keepalive and the toggle payload end to end.
///
/// Plain tests, not testWidgets — real sockets and Hive writes need the actual
/// event loop, which a widget test's fake clock never runs.
void main() {
  late HttpServer server;
  late int port;
  final serverSockets = <WebSocket>[];
  StreamController<Map<String, dynamic>>? received;

  /// Frames the client sent, decoded.
  Stream<Map<String, dynamic>> clientFrames() => received!.stream;

  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    received = StreamController<Map<String, dynamic>>.broadcast();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      serverSockets.add(socket);
      socket.listen((raw) {
        received?.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }, onError: (_) {}, cancelOnError: false);
    });

    // Reverb driver over plain http resolves to ws://127.0.0.1:<port>/app/<key>.
    await SettingsHiveBox.instance.saveAppSettings(
      AppSettingsData.fromJson({
        'app_mode_delivery_boy': '0',
        'broadcast_driver': 'reverb',
        'broadcast_config': {
          'key': 'test-key',
          'host': '127.0.0.1',
          'port': '$port',
          'scheme': 'http',
        },
      }),
    );
  });

  tearDown(() async {
    // disconnect(), not dispose(): dispose closes the broadcast controller for
    // good, and the service is a singleton shared by every test in this file.
    MaintenanceSocketService.instance.disconnect();
    for (final socket in serverSockets) {
      await socket.close();
    }
    serverSockets.clear();
    await received?.close();
    received = null;
    await server.close(force: true);
    await HiveTestHelper.tearDown(settingsBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  /// Waits for the server to accept the client's connection.
  Future<WebSocket> awaitConnection() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (serverSockets.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(serverSockets, isNotEmpty, reason: 'client never connected');
    return serverSockets.first;
  }

  /// The handshake the real server opens with, which triggers subscription.
  void sendConnectionEstablished(WebSocket socket, {int activityTimeout = 120}) {
    socket.add(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({
          'socket_id': '123.456',
          'activity_timeout': activityTimeout,
        }),
      }),
    );
  }

  void sendToggled(
    WebSocket socket, {
    String surface = 'delivery_boy',
    int mode = 1,
    dynamic remark = const {'en': 'Back at 6pm'},
  }) {
    socket.add(
      jsonEncode({
        'event': 'maintenance.toggled',
        'channel': 'maintenance',
        'data': jsonEncode({
          'surface': surface,
          'mode': mode,
          'remark': remark,
        }),
      }),
    );
  }

  test('subscribes to the maintenance channel once the handshake lands', () async {
    printTestDivider('subscribes to the maintenance channel once the handshake lands');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();

    final subscribe = clientFrames().firstWhere(
      (f) => f['event'] == 'pusher:subscribe',
    );
    sendConnectionEstablished(socket);
    final frame = await subscribe.timeout(const Duration(seconds: 5));

    printTestLog('subscribe channel → expected: "maintenance", actual: "${frame['data']['channel']}"');
    expect(frame['data']['channel'], 'maintenance');
  });

  test('answers a server ping with a pong', () async {
    printTestDivider('answers a server ping with a pong');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final pong = clientFrames().firstWhere((f) => f['event'] == 'pusher:pong');
    socket.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
    final frame = await pong.timeout(const Duration(seconds: 5));

    printTestLog('reply event → expected: "pusher:pong", actual: "${frame['event']}"');
    expect(frame['event'], 'pusher:pong');
  });

  test('emits the updated settings when this surface is toggled on', () async {
    printTestDivider('emits the updated settings when this surface is toggled on');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final toggled = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(socket, mode: 1, remark: const {'en': 'Back at 6pm'});
    final settings = await toggled.timeout(const Duration(seconds: 5));

    printTestLog('appModeDeliveryBoy → expected: "1", actual: "${settings.appModeDeliveryBoy}"');
    expect(settings.appModeDeliveryBoy, '1');
    printTestLog(
      'remark → expected: "Back at 6pm", actual: "${settings.appModeDeliveryBoyRemark}"',
    );
    expect(settings.appModeDeliveryBoyRemark, 'Back at 6pm');
  });

  test('persists the toggled mode to the settings box', () async {
    printTestDivider('persists the toggled mode to the settings box');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final toggled = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(socket, mode: 1);
    await toggled.timeout(const Duration(seconds: 5));

    final stored = SettingsHiveBox.instance.getAppSettings();
    printTestLog('stored mode → expected: "1", actual: "${stored?.appModeDeliveryBoy}"');
    expect(stored?.appModeDeliveryBoy, '1');
  });

  test('emits again when maintenance is switched back off', () async {
    printTestDivider('emits again when maintenance is switched back off');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final firstToggle = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(socket, mode: 1);
    await firstToggle.timeout(const Duration(seconds: 5));

    final secondToggle = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(socket, mode: 0);
    final settings = await secondToggle.timeout(const Duration(seconds: 5));

    printTestLog('appModeDeliveryBoy → expected: "0", actual: "${settings.appModeDeliveryBoy}"');
    expect(settings.appModeDeliveryBoy, '0');
  });

  test('ignores a toggle aimed at another surface', () async {
    printTestDivider('ignores a toggle aimed at another surface');
    // The same channel carries toggles for the customer and seller apps too.
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    var emitted = false;
    final sub = MaintenanceSocketService.instance.onToggled.listen(
      (_) => emitted = true,
    );
    addTearDown(sub.cancel);

    sendToggled(socket, surface: 'customer', mode: 1);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    printTestLog('emitted → expected: false, actual: $emitted');
    expect(emitted, isFalse);
    final stored = SettingsHiveBox.instance.getAppSettings();
    printTestLog('stored mode → expected: unchanged "0", actual: "${stored?.appModeDeliveryBoy}"');
    expect(stored?.appModeDeliveryBoy, '0');
  });

  test('falls back to the English remark when the active language has none', () async {
    printTestDivider('falls back to the English remark when the active language has none');
    await SettingsHiveBox.instance.setLanguageCode('ur');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final toggled = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(socket, remark: const {'en': 'Back at 6pm', 'ur': ''});
    final settings = await toggled.timeout(const Duration(seconds: 5));

    printTestLog(
      'remark → expected: "Back at 6pm", actual: "${settings.appModeDeliveryBoyRemark}"',
    );
    expect(settings.appModeDeliveryBoyRemark, 'Back at 6pm');
  });

  test('uses the remark for the active language when there is one', () async {
    printTestDivider('uses the remark for the active language when there is one');
    await SettingsHiveBox.instance.setLanguageCode('ur');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final toggled = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(
      socket,
      remark: const {'en': 'Back at 6pm', 'ur': 'شام 6 بجے واپس'},
    );
    final settings = await toggled.timeout(const Duration(seconds: 5));

    printTestLog(
      'remark → expected: "شام 6 بجے واپس", actual: "${settings.appModeDeliveryBoyRemark}"',
    );
    expect(settings.appModeDeliveryBoyRemark, 'شام 6 بجے واپس');
  });

  test('survives a malformed frame without dropping the connection', () async {
    printTestDivider('survives a malformed frame without dropping the connection');
    MaintenanceSocketService.instance.connect();
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    socket.add('not json at all');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // A good frame right after still gets through.
    final toggled = MaintenanceSocketService.instance.onToggled.first;
    sendToggled(socket, mode: 1);
    final settings = await toggled.timeout(const Duration(seconds: 5));

    printTestLog('appModeDeliveryBoy → expected: "1", actual: "${settings.appModeDeliveryBoy}"');
    expect(settings.appModeDeliveryBoy, '1');
  });

  test('does not connect when the settings carry no broadcast key', () async {
    printTestDivider('does not connect when the settings carry no broadcast key');
    await SettingsHiveBox.instance.saveAppSettings(
      AppSettingsData.fromJson({
        'app_mode_delivery_boy': '0',
        'broadcast_driver': 'reverb',
        'broadcast_config': {'host': '127.0.0.1', 'port': '$port'},
      }),
    );

    MaintenanceSocketService.instance.connect();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    printTestLog('server connections → expected: 0, actual: ${serverSockets.length}');
    expect(serverSockets, isEmpty);
  });

  test('a second connect call is a no-op while already connected', () async {
    printTestDivider('a second connect call is a no-op while already connected');
    MaintenanceSocketService.instance.connect();
    await awaitConnection();

    MaintenanceSocketService.instance.connect();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    printTestLog('server connections → expected: 1, actual: ${serverSockets.length}');
    expect(serverSockets.length, 1);
  });

  test('disconnect closes the socket and lets a later connect reopen it', () async {
    printTestDivider('disconnect closes the socket and lets a later connect reopen it');
    MaintenanceSocketService.instance.connect();
    await awaitConnection();

    MaintenanceSocketService.instance.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    MaintenanceSocketService.instance.connect();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (serverSockets.length < 2 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    printTestLog('server connections → expected: 2, actual: ${serverSockets.length}');
    expect(serverSockets.length, 2);
  });
}
