import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AddFcmTokenState {}

final class AddFcmTokenInitial extends AddFcmTokenState {}

final class AddFcmTokenLoading extends AddFcmTokenState {}

final class AddFcmTokenLoaded extends AddFcmTokenState {}

final class AddFcmTokenError extends AddFcmTokenState {
  final String message;
  AddFcmTokenError(this.message);
}

class AddFcmTokenCubit extends Cubit<AddFcmTokenState>
    with ApiErrorGuard<AddFcmTokenState> {
  final AuthRepository _repository;

  AddFcmTokenCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(AddFcmTokenInitial());

  Future<void> addFcmToken({
    required String fcmToken,
    required String platform,
  }) async {
    emit(AddFcmTokenLoading());
    await guard(() async {
      await _repository.addFcmToken(fcmToken: fcmToken, platform: platform);
      emit(AddFcmTokenLoaded());
    }, onError: (msg) => emit(AddFcmTokenError(msg)));
  }
}
