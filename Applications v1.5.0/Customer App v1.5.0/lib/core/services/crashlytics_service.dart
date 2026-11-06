import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    return _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
  }

  Future<void> log(String message) => _crashlytics.log(message);

  Future<void> setUserId(String id) => _crashlytics.setUserIdentifier(id);
}
