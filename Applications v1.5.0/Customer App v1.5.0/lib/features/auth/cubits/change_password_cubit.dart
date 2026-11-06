import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ────────────────────────────────────────────────────────────────────
sealed class ChangePasswordState {}

final class ChangePasswordInitial extends ChangePasswordState {}

final class ChangePasswordLoading extends ChangePasswordState {}

final class ChangePasswordLoaded extends ChangePasswordState {
  final String message;
  ChangePasswordLoaded(this.message);
}

final class ChangePasswordError extends ChangePasswordState {
  final String message;
  ChangePasswordError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────
class ChangePasswordCubit extends Cubit<ChangePasswordState>
    with ApiErrorGuard<ChangePasswordState> {
  final AuthRepository _repository;

  ChangePasswordCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(ChangePasswordInitial());

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    emit(ChangePasswordLoading());
    await guard(() async {
      final response = await _repository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      final msg =
          response['message']?.toString() ??
          LocalizationService.instance.translate(
            LanguageLabelKeys.passwordChangedSuccess,
          );
      emit(ChangePasswordLoaded(msg));
    }, onError: (msg) => emit(ChangePasswordError(msg)));
  }

  void reset() => emit(ChangePasswordInitial());
}
