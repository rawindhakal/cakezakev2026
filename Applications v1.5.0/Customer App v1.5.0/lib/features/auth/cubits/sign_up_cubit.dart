import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../models/auth_model.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class SignUpState {}

final class SignUpInitial extends SignUpState {}

final class SignUpLoading extends SignUpState {}

final class SignUpLoaded extends SignUpState {
  final String message;
  final AuthModel? auth;

  SignUpLoaded(this.message, {this.auth});
}

final class SignUpEmailOtpRequired extends SignUpState {
  final String message;
  SignUpEmailOtpRequired(this.message);
}

final class SignUpPhoneOtpSent extends SignUpState {
  final String verificationId;
  SignUpPhoneOtpSent(this.verificationId);
}

final class SignUpError extends SignUpState {
  final String message;
  SignUpError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class SignUpCubit extends Cubit<SignUpState> {
  final AuthRepository _repository;

  SignUpCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(SignUpInitial());

  Future<void> signUp({
    required String name,
    String? mobile,
    String? password,
    String? type,
    String? email,
    String? profileImagePath,
    String? friendsCode,
    String? phoneAuthType,
    String? languageId,
    String? countryCode,
    String? countryId,
  }) async {
    emit(SignUpLoading());
    try {
      final auth = await _repository.signUp(
        name: name,
        mobile: mobile,
        password: password,
        type: type,
        email: email,
        profileImagePath: profileImagePath,
        friendsCode: friendsCode,
        phoneAuthType: phoneAuthType,
        languageId: languageId,
        countryCode: countryCode,
        countryId: countryId,
      );
      final msg =
          auth.message ??
          LocalizationService.instance.translate(
            LanguageLabelKeys.registrationSuccessful,
          );
      if (auth.data?.accessToken != null &&
          auth.data!.accessToken!.isNotEmpty) {
        await AuthHiveBox.instance.saveLoginData(userLogin: auth);
        AnalyticsService.instance.logEvent(
          AppConstants.eventSignUp,
          parameters: {AppConstants.paramMethod: type ?? 'unknown'},
        );
        emit(SignUpLoaded(msg, auth: auth));
      } else {
        emit(SignUpLoaded(msg));
      }
    } on ApiException catch (e) {
      emit(SignUpError(e.message));
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'signUp failed',
      );
      emit(
        SignUpError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? mobile,
    String? countryCode,
    String? countryId,
    String? friendsCode,
    String? languageId,
  }) async {
    emit(SignUpLoading());
    try {
      final auth = await _repository.signUp(
        name: name,
        email: email,
        password: password,
        mobile: mobile,
        countryCode: countryCode,
        countryId: countryId,
        type: 'email',
        phoneAuthType: 'password',
        friendsCode: friendsCode,
        languageId: languageId,
      );
      emit(
        SignUpEmailOtpRequired(
          auth.message ??
              LocalizationService.instance.translate(
                LanguageLabelKeys.otpSentToEmail,
              ),
        ),
      );
    } on ApiException catch (e) {
      emit(SignUpError(e.message));
    } catch (_) {
      emit(
        SignUpError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> sendPhoneOtpForSignUp({
    required String phoneNumber,
    required String countryCode,
  }) async {
    emit(SignUpLoading());
    try {
      final verificationId = await _repository.sendPhoneOtpAndGetVerificationId(
        phoneNumber: phoneNumber,
        countryCode: countryCode,
      );
      emit(SignUpPhoneOtpSent(verificationId));
    } on ApiException catch (e) {
      emit(SignUpError(e.message));
    } catch (_) {
      emit(
        SignUpError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(SignUpInitial());
}
