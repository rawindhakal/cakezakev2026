import 'package:customer/features/auth/models/auth_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../../../features/auth/repositories/auth_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class ProfileUpdateState {}

final class ProfileUpdateInitial extends ProfileUpdateState {}

final class ProfileUpdateLoading extends ProfileUpdateState {}

final class ProfileUpdateLoaded extends ProfileUpdateState {
  final AuthModel profile;
  ProfileUpdateLoaded(this.profile);
}

final class ProfileUpdateError extends ProfileUpdateState {
  final String message;
  ProfileUpdateError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class ProfileUpdateCubit extends Cubit<ProfileUpdateState> {
  final AuthRepository _repository;

  ProfileUpdateCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(ProfileUpdateInitial());

  Future<void> updateProfile({
    required String name,
    String? mobile,
    String? email,
    String? profileImagePath,
    String? countryId,
    String? countryCode,
  }) async {
    emit(ProfileUpdateLoading());
    try {
      final userProfile = await _repository.updateProfile(
        name: name,
        mobile: mobile,
        email: email,
        profileImagePath: profileImagePath,
        countryId: countryId,
        countryCode: countryCode,
      );
      await AuthHiveBox.instance.updateUserSession(updated: userProfile);
      final data = userProfile.data;
      AnalyticsService.instance.logEvent(AppConstants.eventProfileUpdate);
      emit(
        ProfileUpdateLoaded(
          data != null ? AuthModel.fromJson(data.toJson()) : AuthModel(),
        ),
      );
    } on ApiException catch (e) {
      emit(ProfileUpdateError(e.message));
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'updateProfile failed',
      );
      emit(
        ProfileUpdateError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
