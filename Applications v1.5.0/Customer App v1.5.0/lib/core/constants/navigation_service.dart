import 'dart:async';

import 'package:flutter/material.dart';

class AppNavigator {
  AppNavigator._();

  static final Completer<void> _ready = Completer<void>();

  /// Completes once the app has navigated away from the splash screen.
  /// Deep link handling awaits this so cold-start links aren't pushed
  /// before the navigator has a route to push on top of.
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

  static NavigatorState of(BuildContext context, {bool rootNavigator = false}) {
    return Navigator.of(context, rootNavigator: rootNavigator);
  }
}
