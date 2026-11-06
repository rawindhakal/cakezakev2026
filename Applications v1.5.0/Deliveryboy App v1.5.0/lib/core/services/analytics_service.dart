import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around Firebase Analytics for logging events and screen views.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Navigator observer that auto-logs screen views as the user navigates.
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Logs a custom analytics event with optional parameters.
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  /// Associates the current session with a user id (or clears it if null).
  Future<void> setUserId(String? id) => _analytics.setUserId(id: id);

  /// Logs a screen view event for the given screen name.
  Future<void> setCurrentScreen(String screenName) {
    return _analytics.logScreenView(screenName: screenName);
  }
}
