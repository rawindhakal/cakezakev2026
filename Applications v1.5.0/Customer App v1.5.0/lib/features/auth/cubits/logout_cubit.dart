import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class LogoutState {}

final class LogoutInitial extends LogoutState {}

final class LogoutLoading extends LogoutState {}

final class LogoutLoaded extends LogoutState {}

final class LogoutError extends LogoutState {
  final String message;
  LogoutError(this.message);
}

class LogoutCubit extends Cubit<LogoutState> with ApiErrorGuard<LogoutState> {
  final AuthRepository _repository;

  LogoutCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(LogoutInitial());

  Future<void> logout() async {
    emit(LogoutLoading());
    await guard(() async {
      await _repository.logout();
      await AuthHiveBox.instance.clearAuth();
      emit(LogoutLoaded());
    }, onError: (msg) => emit(LogoutError(msg)));
  }
}
