import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserId(String? id) => _analytics.setUserId(id: id);

  Future<void> setCurrentScreen(String screenName) {
    return _analytics.logScreenView(screenName: screenName);
  }
}
