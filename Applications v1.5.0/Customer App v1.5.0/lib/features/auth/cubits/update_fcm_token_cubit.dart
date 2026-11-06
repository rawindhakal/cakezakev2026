import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class UpdateFcmTokenState {}

final class UpdateFcmTokenInitial extends UpdateFcmTokenState {}

final class UpdateFcmTokenLoading extends UpdateFcmTokenState {}

final class UpdateFcmTokenLoaded extends UpdateFcmTokenState {}

final class UpdateFcmTokenError extends UpdateFcmTokenState {
  final String message;
  UpdateFcmTokenError(this.message);
}

class UpdateFcmTokenCubit extends Cubit<UpdateFcmTokenState>
    with ApiErrorGuard<UpdateFcmTokenState> {
  final AuthRepository _repository;

  UpdateFcmTokenCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(UpdateFcmTokenInitial());

  Future<void> updateFcmToken({
    required String fcmToken,
    required String platform,
    required String languageId,
  }) async {
    emit(UpdateFcmTokenLoading());
    await guard(() async {
      await _repository.updateFcmToken(
        fcmToken: fcmToken,
        platform: platform,
        languageId: languageId,
      );
      emit(UpdateFcmTokenLoaded());
    }, onError: (msg) => emit(UpdateFcmTokenError(msg)));
  }
}
