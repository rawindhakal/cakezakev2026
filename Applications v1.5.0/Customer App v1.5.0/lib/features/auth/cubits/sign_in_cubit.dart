import 'package:customer/features/auth/models/auth_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/clarity_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class SignInState {}

final class SignInInitial extends SignInState {}

final class SignInLoading extends SignInState {}

final class SignInCancelled extends SignInState {}

final class SignInLoaded extends SignInState {
  final AuthModel user;
  SignInLoaded(this.user);
}

final class SignInError extends SignInState {
  final String message;
  SignInError(this.message);
}

final class SignInUserNotFound extends SignInState {
  final String? email;
  final String? name;
  final String? phone;
  final String? provider; // 'google', 'apple', or null for email/phone
  SignInUserNotFound({this.email, this.name, this.phone, this.provider});
}

// ── Helpers ──────────────────────────────────────────────────────────────────
bool _isUserNotFound(ApiException e) => [
  'USER_NOT_FOUND',
  'USER_NOT_EXIST',
  'EMAIL_NOT_VERIFIED',
].contains(e.messageStatusCode);

// ── Cubit ────────────────────────────────────────────────────────────────────
class SignInCubit extends Cubit<SignInState> {
  final AuthRepository _repository;

  SignInCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(SignInInitial());

  void _onLoginSuccess(AuthModel user, String method) {
    final userId = user.data?.id?.toString();
    AnalyticsService.instance.logEvent(
      AppConstants.eventLogin,
      parameters: {AppConstants.paramMethod: method},
    );
    if (userId != null) {
      AnalyticsService.instance.setUserId(userId);
      CrashlyticsService.instance.setUserId(userId);
      ClarityService.setCustomTag(AppConstants.paramUserId, userId);
    }
  }

  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String type,
    required String phoneAuthType,
    String? languageId,
    required String countryCode,
  }) async {
    emit(SignInLoading());
    try {
      final user = await _repository.verifyPhoneOtp(
        phoneNumber: phoneNumber,
        type: type,
        phoneAuthType: phoneAuthType,
        languageId: languageId,
        countryCode: countryCode,
      );
      await AuthHiveBox.instance.saveLoginData(userLogin: user);
      _onLoginSuccess(user, AppConstants.loginMethodPhoneOtp);
      emit(SignInLoaded(user));
    } on ApiException catch (e) {
      if (_isUserNotFound(e)) {
        emit(SignInUserNotFound(phone: phoneNumber));
      } else {
        emit(SignInError(e.message));
      }
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'verifyPhoneOtp failed',
      );
      emit(
        SignInError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required String countryCode,
  }) async {
    emit(SignInLoading());
    try {
      await _repository.sendPhoneOtp(
        phoneNumber: phoneNumber,
        countryCode: countryCode,
      );
      emit(SignInInitial());
    } on ApiException catch (e) {
      emit(SignInError(e.message));
    } catch (_) {
      emit(
        SignInError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loginWithPhonePassword({
    required String id,
    required String password,
    required String type,
    required String phoneAuthType,
    required String countryCode,
    String? languageId,
  }) async {
    emit(SignInLoading());
    try {
      final user = await _repository.loginWithPhonePassword(
        id: id,
        password: password,
        type: type,
        phoneAuthType: phoneAuthType,
        countryCode: countryCode,
        languageId: languageId,
      );
      await AuthHiveBox.instance.saveLoginData(userLogin: user);
      _onLoginSuccess(user, AppConstants.loginMethodPhonePassword);
      emit(SignInLoaded(user));
    } on ApiException catch (e) {
      if (_isUserNotFound(e)) {
        emit(SignInUserNotFound(phone: id));
      } else {
        emit(SignInError(e.message));
      }
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'loginWithPhonePassword failed',
      );
      emit(
        SignInError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loginWithEmailPassword({
    required String id,
    required String password,
    required String type,
    String? languageId,
  }) async {
    emit(SignInLoading());
    try {
      final user = await _repository.loginWithEmailPassword(
        id: id,
        password: password,
        type: type,
        languageId: languageId,
      );
      await AuthHiveBox.instance.saveLoginData(userLogin: user);
      _onLoginSuccess(user, AppConstants.loginMethodEmailPassword);
      emit(SignInLoaded(user));
    } on ApiException catch (e) {
      emit(SignInError(e.message));
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'loginWithEmailPassword failed',
      );
      emit(
        SignInError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loginWithGoogle({
    required String type,
    String? languageId,
  }) async {
    emit(SignInLoading());
    String? googleEmail;
    String? googleName;
    try {
      // Firebase first — capture email/name before the backend call can throw
      final credential = await _repository.signInWithGoogleFirebase();
      googleEmail = credential.user?.email;
      googleName = credential.user?.displayName;

      final user = await _repository.loginWithGoogle(
        type: type,
        languageId: languageId,
        preAuthEmail: googleEmail,
      );
      await AuthHiveBox.instance.saveLoginData(userLogin: user);
      _onLoginSuccess(user, AppConstants.loginMethodGoogle);
      emit(SignInLoaded(user));
    } on ApiException catch (e) {
      if (e.isCancelled) {
        emit(SignInCancelled());
      } else if (_isUserNotFound(e)) {
        emit(
          SignInUserNotFound(
            email: googleEmail,
            name: googleName,
            provider: 'google',
          ),
        );
      } else {
        emit(SignInError(e.message));
      }
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'loginWithGoogle failed',
      );
      emit(
        SignInError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loginWithApple({
    required String type,
    String? languageId,
  }) async {
    emit(SignInLoading());
    String? appleEmail;
    String? appleName;
    try {
      // Firebase first — capture email/name before the backend call can throw
      final credential = await _repository.signInWithAppleFirebase();
      appleEmail = credential.user?.email;
      appleName = credential.user?.displayName;

      final user = await _repository.loginWithApple(
        type: type,
        languageId: languageId,
        preAuthEmail: appleEmail,
      );
      await AuthHiveBox.instance.saveLoginData(userLogin: user);
      _onLoginSuccess(user, AppConstants.loginMethodApple);
      emit(SignInLoaded(user));
    } on ApiException catch (e) {
      if (e.isCancelled) {
        emit(SignInCancelled());
      } else if (_isUserNotFound(e)) {
        emit(
          SignInUserNotFound(
            email: appleEmail,
            name: appleName,
            provider: 'apple',
          ),
        );
      } else {
        emit(SignInError(e.message));
      }
    } catch (error, stack) {
      CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: 'loginWithApple failed',
      );
      emit(
        SignInError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(SignInInitial());
}
