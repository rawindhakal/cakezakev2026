import 'package:customer/features/auth/models/auth_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class CustomSmsSendPhoneOtpState {}

final class CustomSmsSendPhoneOtpInitial extends CustomSmsSendPhoneOtpState {}

final class CustomSmsSendPhoneOtpLoading extends CustomSmsSendPhoneOtpState {}

final class CustomSmsSendPhoneOtpLoaded extends CustomSmsSendPhoneOtpState {
  final AuthModel user;
  CustomSmsSendPhoneOtpLoaded(this.user);
}

final class CustomSmsSendPhoneOtpError extends CustomSmsSendPhoneOtpState {
  final String message;
  CustomSmsSendPhoneOtpError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class CustomSmsSendPhoneOtpCubit extends Cubit<CustomSmsSendPhoneOtpState>
    with ApiErrorGuard<CustomSmsSendPhoneOtpState> {
  final AuthRepository _repository;

  CustomSmsSendPhoneOtpCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(CustomSmsSendPhoneOtpInitial());

  Future<void> customSmsSendPhoneOtp({required String phoneNumber}) async {
    emit(CustomSmsSendPhoneOtpLoading());
    await guard(() async {
      final user = await _repository.customSmsSendPhoneOtp(
        phoneNumber: phoneNumber,
      );
      emit(CustomSmsSendPhoneOtpLoaded(user));
    }, onError: (msg) => emit(CustomSmsSendPhoneOtpError(msg)));
  }

  void reset() => emit(CustomSmsSendPhoneOtpInitial());
}
