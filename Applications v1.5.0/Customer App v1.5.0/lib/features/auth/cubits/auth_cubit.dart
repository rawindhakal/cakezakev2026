import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_parameters.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../repositories/auth_repository.dart';

enum AuthType { email, phone, google, apple, phoneWithPassword }

enum OtpAuthType { email, firebase, custom }

enum PhoneAuthType { password, otp, social }

extension PhoneAuthTypeApi on PhoneAuthType {
  /// API value expected by `phone_auth_type` param — `.name` alone doesn't match it.
  String get apiValue => switch (this) {
    PhoneAuthType.password => ApiParameters.phoneAuthPassword,
    PhoneAuthType.otp => ApiParameters.phoneAuthOtp,
    PhoneAuthType.social => name,
  };
}

enum OtpVerifyMethod { firebase, customSms }

// ── States ──────────────────────────────────────────────────────────────────
sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthAuthenticated extends AuthState {}

final class AuthUnauthenticated extends AuthState {}

final class AuthLoading extends AuthState {}

// ── Cubit ────────────────────────────────────────────────────────────────────
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(AuthInitial());

  bool get isAuthenticated =>
      AuthHiveBox.instance.isLoggedIn &&
      (AuthHiveBox.instance.getToken()?.isNotEmpty ?? false);

  void checkAuth() {
    if (isAuthenticated) {
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await _repository.logout();
    } catch (_) {
      // ignore API errors on logout — clear local data regardless
    }
    await AuthHiveBox.instance.clearAuth();
    emit(AuthUnauthenticated());
  }
}
