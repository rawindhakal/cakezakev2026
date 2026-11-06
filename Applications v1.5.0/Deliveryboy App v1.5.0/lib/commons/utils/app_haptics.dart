import 'dart:io';

import 'package:flutter/services.dart';

/// Single entry point for haptic feedback across the app, so every screen
/// uses the same vocabulary of feels instead of picking raw
/// [HapticFeedback] calls ad hoc.
///
///  - [tick]    — crisp selection click: tab switch, wheel/picker detents.
///  - [tap]     — light tap: add/remove from cart, favorite, toggles.
///  - [impact]  — firmer thud: a threshold crossed (swipe-switch, spin start).
///  - [success] — light + medium double pulse: order placed, promo applied.
///  - [warning] — single medium: a limit reached.
///  - [error]   — heavy + medium double pulse: a failed action.
///
/// On Android this goes through the native `AppHapticsChannel` (see
/// MainActivity): Flutter's [HapticFeedback] uses performHapticFeedback,
/// which budget devices without predefined effects drop silently. iOS keeps
/// [HapticFeedback], which maps to the Taptic Engine directly.
///
/// Calls closer together than [_minGap] are dropped so rapid repeats
/// (fast stepper taps, a spinning wheel's ticks) never blur into a buzz.
abstract final class AppHaptics {
  /// Master switch — e.g. bind to a user setting.
  static bool enabled = true;

  static const _channel = MethodChannel('app.cakezake/haptics');
  static const _minGap = Duration(milliseconds: 45);
  static const _pulseGap = Duration(milliseconds: 90);
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static bool _canFire() {
    if (!enabled) return false;
    final now = DateTime.now();
    if (now.difference(_last) < _minGap) return false;
    _last = now;
    return true;
  }

  static Future<void> _play(
    String type,
    Future<void> Function() fallback,
  ) async {
    if (!Platform.isAndroid) return fallback();
    try {
      await _channel.invokeMethod<void>('play', {'type': type});
    } on MissingPluginException {
      await fallback();
    }
  }

  static Future<void> _tick() => _play('tick', HapticFeedback.selectionClick);
  static Future<void> _light() => _play('light', HapticFeedback.lightImpact);
  static Future<void> _medium() => _play('medium', HapticFeedback.mediumImpact);
  static Future<void> _heavy() => _play('heavy', HapticFeedback.heavyImpact);

  static void tick() {
    if (_canFire()) _tick();
  }

  static void tap() {
    if (_canFire()) _light();
  }

  static void impact() {
    if (_canFire()) _medium();
  }

  static void warning() {
    if (_canFire()) _medium();
  }

  static Future<void> success() async {
    if (!_canFire()) return;
    await _light();
    await Future<void>.delayed(_pulseGap);
    await _medium();
  }

  static Future<void> error() async {
    if (!_canFire()) return;
    await _heavy();
    await Future<void>.delayed(_pulseGap);
    await _medium();
  }
}
