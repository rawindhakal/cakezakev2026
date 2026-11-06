import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';
import 'package:deliveryboy/features/notifications/repositories/notification_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef NotificationSaveState = AsyncState<AppNotificationSettings>;
typedef NotificationSaveInitial = AsyncInitial<AppNotificationSettings>;
typedef NotificationSaveLoading = AsyncLoading<AppNotificationSettings>;
typedef NotificationSaveLoaded = AsyncLoaded<AppNotificationSettings>;
typedef NotificationSaveError = AsyncError<AppNotificationSettings>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Saves the rider's notification (mobile/SMS/email) status preferences.
class NotificationSaveCubit extends BaseAsyncCubit<AppNotificationSettings> {
  final NotificationRepository _repository;

  NotificationSaveCubit({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  /// Submits the updated per-event notification channel selections.
  Future<void> saveNotificationSettings({required List<Events> preferences}) =>
      run(() => _repository.saveNotificationSettings(preferences: preferences));
}
