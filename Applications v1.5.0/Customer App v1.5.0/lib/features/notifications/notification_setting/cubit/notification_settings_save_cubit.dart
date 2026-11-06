import 'package:customer/features/notifications/notification_setting/repositories/notification_settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/notifications/notification_setting/models/notification_setting_model.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class NotificationSettingsSaveState {}

final class NotificationSettingsSaveInitial
    extends NotificationSettingsSaveState {}

final class NotificationSettingsSaveLoading
    extends NotificationSettingsSaveState {}

final class NotificationSettingsSaveLoaded
    extends NotificationSettingsSaveState {
  final AppNotificationSettings notificationSettings;
  NotificationSettingsSaveLoaded(this.notificationSettings);
}

final class NotificationSettingsSaveError
    extends NotificationSettingsSaveState {
  final String message;
  NotificationSettingsSaveError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class NotificationSettingsSaveCubit extends Cubit<NotificationSettingsSaveState>
    with ApiErrorGuard<NotificationSettingsSaveState> {
  final NotificationSettingsRepository _repository;

  NotificationSettingsSaveCubit({NotificationSettingsRepository? repository})
    : _repository = repository ?? NotificationSettingsRepository(),
      super(NotificationSettingsSaveInitial());

  Future<void> saveNotificationSettings({
    required List<Events> preferences,
  }) async {
    emit(NotificationSettingsSaveLoading());
    await guard(() async {
      final result = await _repository.saveNotificationSettings(
        preferences: preferences,
      );
      emit(NotificationSettingsSaveLoaded(result));
    }, onError: (msg) => emit(NotificationSettingsSaveError(msg)));
  }
}
