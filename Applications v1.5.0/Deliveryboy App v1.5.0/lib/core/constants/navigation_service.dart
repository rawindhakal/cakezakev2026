import 'dart:async';

import 'package:flutter/material.dart';

/// Thin wrapper around [Navigator] so screens never call it directly.
class AppNavigator {
  AppNavigator._();

  static final Completer<void> _ready = Completer<void>();

  /// Completes once the app has navigated away from the splash screen.
  /// Anything that pushes a route onto the root navigator from outside the
  /// splash flow (e.g. a dialog triggered by a settings listener) should
  /// await this first — otherwise it can land while splash's own
  /// pushReplacementNamed is in flight, and that call replaces whatever is
  /// currently on top of the stack, silently wiping out the dialog instead
  /// of splash.
  static Future<void> get readyFuture => _ready.future;

  static void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  static Future<T?> pushNamed<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T, TO>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  static Future<T?> pushNamedAndRemoveUntil<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static Future<T?> pushNamedAndRemoveUntilRoute<T>(
    BuildContext context,
    String routeName,
    String keepUntilRouteName, {
    Object? arguments,
  }) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      routeName,
      ModalRoute.withName(keepUntilRouteName),
      arguments: arguments,
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }

  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  static NavigatorState of(BuildContext context) {
    return Navigator.of(context);
  }
}
