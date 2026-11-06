import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../models/auth_model.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class VerifyOtpState {}

final class VerifyOtpInitial extends VerifyOtpState {}

final class VerifyOtpLoading extends VerifyOtpState {}

final class VerifyOtpLoaded extends VerifyOtpState {
  final String message;
  final AuthModel auth;
  VerifyOtpLoaded(this.message, {required this.auth});
}

final class VerifyOtpError extends VerifyOtpState {
  final String message;
  VerifyOtpError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class VerifyOtpCubit extends Cubit<VerifyOtpState>
    with ApiErrorGuard<VerifyOtpState> {
  final AuthRepository _repository;

  VerifyOtpCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(VerifyOtpInitial());

  Future<void> verifyEmail({required String email, required String otp}) async {
    emit(VerifyOtpLoading());
    await guard(() async {
      final auth = await _repository.verifyEmail(email: email, otp: otp);
      final msg =
          auth.message ??
          LocalizationService.instance.translate(
            LanguageLabelKeys.emailVerifiedSuccess,
          );
      if (auth.data?.accessToken != null &&
          auth.data!.accessToken!.isNotEmpty) {
        await AuthHiveBox.instance.saveLoginData(userLogin: auth);
        emit(VerifyOtpLoaded(msg, auth: auth));
      } else {
        emit(
          VerifyOtpError(
            LocalizationService.instance.translate(
              LanguageLabelKeys.verificationFailedTryAgain,
            ),
          ),
        );
      }
    }, onError: (msg) => emit(VerifyOtpError(msg)));
  }

  Future<void> verifyPhoneOtpAndSignUp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String mobile,
    String? email,
    String? password,
    String? phoneAuthType,
    String? friendsCode,
    String? languageId,
    String? countryCode,
    String? countryId,
  }) async {
    emit(VerifyOtpLoading());
    await guard(() async {
      await _repository.verifyFirebasePhoneOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final auth = await _repository.signUp(
        name: name,
        mobile: mobile,
        email: email,
        password: password,
        type: 'phone',
        phoneAuthType: phoneAuthType ?? 'otp',
        friendsCode: friendsCode,
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
        emit(VerifyOtpLoaded(msg, auth: auth));
      } else {
        emit(
          VerifyOtpError(
            LocalizationService.instance.translate(
              LanguageLabelKeys.registrationFailedTryAgain,
            ),
          ),
        );
      }
    }, onError: (msg) => emit(VerifyOtpError(msg)));
  }

  void reset() => emit(VerifyOtpInitial());
}
