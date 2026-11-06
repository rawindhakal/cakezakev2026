import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Thin wrapper around Firebase Crashlytics for error reporting and logging.
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Records a non-fatal (or fatal) error to Crashlytics with an optional reason.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    return _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
  }

  /// Appends a custom log message to the Crashlytics session log.
  Future<void> log(String message) => _crashlytics.log(message);

  /// Sets the user identifier attached to subsequent Crashlytics reports.
  Future<void> setUserId(String id) => _crashlytics.setUserIdentifier(id);
}
