import 'package:customer/core/constants/socket_driver.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';

/// Outcome of [SocketUrlResolver.resolve] — either a usable ws(s) base URL
/// for the Pusher-protocol broadcast server, or the reason there isn't one.
class SocketEndpoint {
  const SocketEndpoint._({
    required this.driver,
    this.baseUrl,
    this.unavailableReason,
  });

  /// `scheme://host[:port]/app/{key}` — null when the settings API doesn't
  /// describe a usable Pusher/Reverb connection, in which case
  /// [unavailableReason] explains why.
  final String? baseUrl;

  /// Raw `broadcast_driver` value from the settings API, for logging.
  final String driver;

  /// Human-readable explanation, set only when [baseUrl] is null.
  final String? unavailableReason;

  bool get isResolved => baseUrl != null;
}

/// Builds the realtime broadcast socket URL from the settings API's
/// `broadcast_driver` ("pusher" | "reverb" | "") and `broadcast_config`.
///
/// Shared by every websocket service (chat, maintenance mode, ...) so the
/// driver rules and vendor host format live in one place. Callers decide what
/// an unresolved endpoint means: [MaintenanceSocketService] skips connecting,
/// [ChatSocketService] falls back to the legacy self-hosted server.
abstract final class SocketUrlResolver {
  /// Pusher's own cluster hosts, e.g. `wss://ws-mt1.pusher.com/app/{key}`.
  static const String _pusherHostPrefix = 'wss://ws-';
  static const String _pusherHostSuffix = '.pusher.com';
  static const String _defaultPusherCluster = 'mt1';

  /// Path segment the Pusher protocol expects after the host, before the key.
  static const String _appPath = '/app/';

  /// Handshake query the Pusher protocol expects on the connection URL.
  static const String _handshakeQuery =
      'protocol=7&client=js&version=8.4.0&flash=false';

  static SocketEndpoint resolve() {
    final settings = SettingsHiveBox.instance.getAppSettings();
    final driver = (settings?.broadcastDriver ?? '').toLowerCase();
    final config = settings?.broadcastConfig;
    final key = config?.key ?? '';
    if (key.isEmpty) {
      return SocketEndpoint._(
        driver: driver,
        unavailableReason:
            'no broadcast key (driver="$driver"). '
            'Settings loaded: ${settings != null}',
      );
    }

    switch (SocketDriver.fromValue(driver)) {
      case SocketDriver.pusher:
        final cluster = config?.cluster ?? _defaultPusherCluster;
        return SocketEndpoint._(
          driver: driver,
          baseUrl: '$_pusherHostPrefix$cluster$_pusherHostSuffix$_appPath$key',
        );

      case SocketDriver.reverb:
        final host = config?.host ?? '';
        if (host.isEmpty) {
          return SocketEndpoint._(
            driver: driver,
            unavailableReason: 'reverb driver but no host',
          );
        }
        final scheme = (config?.scheme ?? 'https').toLowerCase();
        final wsScheme = scheme == 'https' ? 'wss' : 'ws';
        final port = config?.port ?? '';
        final portSegment = port.isNotEmpty ? ':$port' : '';
        return SocketEndpoint._(
          driver: driver,
          baseUrl: '$wsScheme://$host$portSegment$_appPath$key',
        );

      case null:
        return SocketEndpoint._(
          driver: driver,
          unavailableReason: 'unrecognised driver="$driver"',
        );
    }
  }

  /// Connection URI for [baseUrl], with the Pusher handshake query attached.
  static Uri handshakeUri(String baseUrl) =>
      Uri.parse('$baseUrl?$_handshakeQuery');
}
