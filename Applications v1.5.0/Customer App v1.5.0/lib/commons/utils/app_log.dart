import 'package:flutter/foundation.dart';

/// Debug-only console logging.
///
/// [debugPrint] is *not* stripped from release builds — it still writes to
/// logcat/os_log, so anything passed to it is readable off a shipped device.
/// Several call sites log material that must not leave the device that way:
/// socket URLs (which embed the broadcast app key), raw chat frames, deep-link
/// URIs and the FCM token. Routing them through here keeps them in debug builds
/// only, since `kDebugMode` is a compile-time constant.
///
/// Callers that already wrap a whole block in `if (kDebugMode)` (the API client
/// and its interceptor) don't need this.
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
