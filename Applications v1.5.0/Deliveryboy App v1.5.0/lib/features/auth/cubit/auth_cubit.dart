import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../repositories/auth_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthAuthenticated extends AuthState {}

final class AuthUnauthenticated extends AuthState {}

final class AuthLoading extends AuthState {}

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Tracks the app-wide authentication state based on locally stored session data.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(AuthInitial());

  bool get isAuthenticated =>
      AuthHiveBox.instance.isLoggedIn &&
      (AuthHiveBox.instance.getToken()?.isNotEmpty ?? false);

  /// Emits authenticated/unauthenticated based on the current local session.
  void checkAuth() {
    if (isAuthenticated) {
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  /// Logs out on the server (best-effort) and clears local auth data.
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
