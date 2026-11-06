import 'package:customer/features/auth/models/auth_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/auth/repositories/auth_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class ProfileDetailState {}

final class ProfileDetailInitial extends ProfileDetailState {}

final class ProfileDetailLoading extends ProfileDetailState {}

final class ProfileDetailLoaded extends ProfileDetailState {
  final AuthModel profile;
  ProfileDetailLoaded(this.profile);
}

final class ProfileDetailError extends ProfileDetailState {
  final String message;
  ProfileDetailError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class ProfileDetailCubit extends Cubit<ProfileDetailState>
    with ApiErrorGuard<ProfileDetailState> {
  final AuthRepository _repository;

  ProfileDetailCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(ProfileDetailInitial());

  Future<void> loadProfile() async {
    emit(ProfileDetailLoading());
    await guard(() async {
      final userProfile = await _repository.getProfile();
      emit(ProfileDetailLoaded(userProfile));
    }, onError: (msg) => emit(ProfileDetailError(msg)));
  }
}
