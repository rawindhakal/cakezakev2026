import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter/material.dart';

extension LocalizationExtensions on BuildContext {
  /// Translate [key] using API-fetched strings. Falls back to [fallback] or the key itself.
  ///
  /// Registers this context as a dependent of the [InheritedNotifier] wrapping
  /// the app (see `main.dart`) so the widget rebuilds automatically when the
  /// active language changes — mirrors how `Directionality.of(context)` keeps
  /// RTL/LTR live. Calling this outside a build (e.g. inside a callback) is
  /// safe: it just resolves the current value without registering a rebuild.
  String translate(String key, {String? fallback}) {
    dependOnInheritedWidgetOfExactType<LocalizationScope>();
    return LocalizationService.instance.translate(key, fallback: fallback);
  }
}
