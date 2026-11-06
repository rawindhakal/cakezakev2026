import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';
import 'package:deliveryboy/features/notifications/repositories/notification_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef NotificationState = AsyncState<AppNotificationSettings>;
typedef NotificationInitial = AsyncInitial<AppNotificationSettings>;
typedef NotificationLoading = AsyncLoading<AppNotificationSettings>;
typedef NotificationLoaded = AsyncLoaded<AppNotificationSettings>;
typedef NotificationError = AsyncError<AppNotificationSettings>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Fetches the rider's notification (mobile/SMS/email) status preferences.
class NotificationCubit extends BaseAsyncCubit<AppNotificationSettings> {
  final NotificationRepository _repository;

  NotificationCubit({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  /// Loads the current notification settings from the server.
  Future<void> getNotificationSettings() =>
      run(() => _repository.getNotificationSettings());

  /* void updateNotificationStatus(int statusId, bool isEmail, bool isMobile) {
    if (state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;
      final updatedStatuses = currentState.notificationSettings.data?.statuses?.map((status) {
        if (status.id == statusId) {
          return status.copyWith(
            isEmailEnabled: isEmail,
            isMobileEnabled: isMobile,
          );
        }
        return status;
      }).toList();

      final updatedData = currentState.notificationSettings.data?.copyWith(
        statuses: updatedStatuses,
      );

      final updatedModel = currentState.notificationSettings.copyWith(data: updatedData);
      emit(NotificationLoaded(updatedModel));
    }
  } */
}
