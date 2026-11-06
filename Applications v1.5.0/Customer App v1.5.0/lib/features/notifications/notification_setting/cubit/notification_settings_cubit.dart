import 'package:customer/features/notifications/notification_setting/repositories/notification_settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/notifications/notification_setting/models/notification_setting_model.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class NotificationSettingsState {}

final class NotificationSettingsInitial extends NotificationSettingsState {}

final class NotificationSettingsLoading extends NotificationSettingsState {}

final class NotificationSettingsLoaded extends NotificationSettingsState {
  final AppNotificationSettings notificationSettings;
  NotificationSettingsLoaded(this.notificationSettings);
}

final class NotificationSettingsError extends NotificationSettingsState {
  final String message;
  NotificationSettingsError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class NotificationSettingsCubit extends Cubit<NotificationSettingsState>
    with ApiErrorGuard<NotificationSettingsState> {
  final NotificationSettingsRepository _repository;

  NotificationSettingsCubit({NotificationSettingsRepository? repository})
    : _repository = repository ?? NotificationSettingsRepository(),
      super(NotificationSettingsInitial());

  Future<void> getNotificationSettings() async {
    emit(NotificationSettingsLoading());
    await guard(() async {
      final result = await _repository.getNotificationSettings();
      emit(NotificationSettingsLoaded(result));
    }, onError: (msg) => emit(NotificationSettingsError(msg)));
  }
}
