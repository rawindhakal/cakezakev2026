import 'package:customer/core/api/api_parameters.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'auth_cubit.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ────────────────────────────────────────────────────────────────────
sealed class ForgotPasswordState {}

final class ForgotPasswordInitial extends ForgotPasswordState {}

final class ForgotPasswordLoading extends ForgotPasswordState {}

final class ForgotPasswordOtpSent extends ForgotPasswordState {
  final String? verificationId;
  ForgotPasswordOtpSent({this.verificationId});
}

final class ForgotPasswordOtpVerified extends ForgotPasswordState {}

final class ForgotPasswordSuccess extends ForgotPasswordState {
  final String message;
  ForgotPasswordSuccess(this.message);
}

final class ForgotPasswordError extends ForgotPasswordState {
  final String message;
  ForgotPasswordError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────
class ForgotPasswordCubit extends Cubit<ForgotPasswordState>
    with ApiErrorGuard<ForgotPasswordState> {
  final AuthRepository _repository;
  String? _verificationId;

  ForgotPasswordCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(ForgotPasswordInitial());

  // ── Phone flow ────────────────────────────────────────────────────────────

  Future<void> verifyPhoneAndSendOtp({
    required String mobile,
    required String countryCode,
    required bool isFirebase,
  }) async {
    emit(ForgotPasswordLoading());
    await guard(() async {
      final res = await _repository.verifyUserExist(
        mobile: mobile,
        countryCode: countryCode,
      );
      final status = res[ApiParameters.status]?.toString();
      final message = res[ApiParameters.message]?.toString();
      if (status == '1' && message == 'user_already_exist') {
        await _sendPhoneOtp(
          mobile: mobile,
          countryCode: countryCode,
          isFirebase: isFirebase,
        );
      } else {
        emit(
          ForgotPasswordError(
            message ??
                LocalizationService.instance.translate(
                  LanguageLabelKeys.userNotFound,
                ),
          ),
        );
      }
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  Future<void> resendPhoneOtp({
    required String mobile,
    required String countryCode,
    required bool isFirebase,
  }) async {
    emit(ForgotPasswordLoading());
    await _sendPhoneOtp(
      mobile: mobile,
      countryCode: countryCode,
      isFirebase: isFirebase,
    );
  }

  Future<void> _sendPhoneOtp({
    required String mobile,
    required String countryCode,
    required bool isFirebase,
  }) async {
    await guard(() async {
      if (isFirebase) {
        final vid = await _repository.sendPhoneOtpAndGetVerificationId(
          phoneNumber: mobile,
          countryCode: countryCode,
        );
        _verificationId = vid;
        emit(ForgotPasswordOtpSent(verificationId: vid));
      } else {
        await _repository.sendCustomSmsForgotPasswordOtp(
          mobile: mobile,
          countryCode: countryCode,
        );
        emit(ForgotPasswordOtpSent());
      }
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  Future<void> verifyFirebaseOtp({required String smsCode}) async {
    if (_verificationId == null) {
      emit(
        ForgotPasswordError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.verificationSessionExpired,
          ),
        ),
      );
      return;
    }
    emit(ForgotPasswordLoading());
    await guard(() async {
      await _repository.verifyFirebasePhoneOtp(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      emit(ForgotPasswordOtpVerified());
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  Future<void> verifyCustomSmsOtp({
    required String mobile,
    required String otp,
    required String countryCode,
  }) async {
    emit(ForgotPasswordLoading());
    await guard(() async {
      await _repository.verifyCustomSmsOtpForForgotPassword(
        mobile: mobile,
        otp: otp,
        countryCode: countryCode,
      );
      emit(ForgotPasswordOtpVerified());
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  Future<void> resetPasswordPhone({
    required String mobile,
    required String countryCode,
    required String password,
    required String passwordConfirmation,
    required String otpVerifyMethod,
  }) async {
    emit(ForgotPasswordLoading());
    await guard(() async {
      final res = await _repository.forgotPassword(
        params: {
          ApiParameters.mobile: mobile,
          ApiParameters.countryCode: countryCode,
          ApiParameters.password: password,
          ApiParameters.passwordConfirmation: passwordConfirmation,
          ApiParameters.type: AuthType.phone.name,
          ApiParameters.otpVerifyMethod: otpVerifyMethod,
        },
      );
      final msg =
          res[ApiParameters.message]?.toString() ??
          LocalizationService.instance.translate(
            LanguageLabelKeys.passwordResetSuccess,
          );
      emit(ForgotPasswordSuccess(msg));
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  // ── Email flow ────────────────────────────────────────────────────────────

  Future<void> sendEmailOtp({required String email}) async {
    emit(ForgotPasswordLoading());
    await guard(() async {
      await _repository.sendEmailForgotPasswordOtp(email: email);
      emit(ForgotPasswordOtpSent());
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  Future<void> resetPasswordEmail({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    emit(ForgotPasswordLoading());
    await guard(() async {
      final res = await _repository.forgotPassword(
        params: {
          ApiParameters.email: email,
          ApiParameters.otp: otp,
          ApiParameters.password: password,
          ApiParameters.passwordConfirmation: passwordConfirmation,
          ApiParameters.type: AuthType.email.name,
        },
      );
      final msg =
          res[ApiParameters.message]?.toString() ??
          LocalizationService.instance.translate(
            LanguageLabelKeys.passwordResetSuccess,
          );
      emit(ForgotPasswordSuccess(msg));
    }, onError: (msg) => emit(ForgotPasswordError(msg)));
  }

  void reset() => emit(ForgotPasswordInitial());
}
