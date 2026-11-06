import 'package:flutter/foundation.dart';

/// Debug-only logger. Compiles to a no-op in release/profile builds.
///
/// Use this instead of calling [debugPrint] directly: [debugPrint] is *not*
/// stripped from release builds, so anything passed to it keeps printing to
/// logcat/Console on real user devices. Several of these logs carry FCM
/// payloads and chat message bodies, which must never leave the device that
/// way.
///
/// [message] is a callback rather than a plain string so the interpolation
/// itself is also skipped in release — no cost for logs that are never shown.
void logDebug(String Function() message) {
  if (kDebugMode) debugPrint(message());
}
