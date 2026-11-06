import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/auth/models/auth_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../repositories/auth_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class CustomSmsVerifyPhoneOtpState {}

final class CustomSmsVerifyPhoneOtpInitial
    extends CustomSmsVerifyPhoneOtpState {}

final class CustomSmsVerifyPhoneOtpLoading
    extends CustomSmsVerifyPhoneOtpState {}

final class CustomSmsVerifyPhoneOtpLoaded extends CustomSmsVerifyPhoneOtpState {
  final AuthModel user;
  CustomSmsVerifyPhoneOtpLoaded(this.user);
}

/// OTP is valid but no account exists for this phone yet.
final class CustomSmsVerifyPhoneOtpUserNotFound
    extends CustomSmsVerifyPhoneOtpState {
  final String phone;
  CustomSmsVerifyPhoneOtpUserNotFound(this.phone);
}

final class CustomSmsVerifyPhoneOtpError extends CustomSmsVerifyPhoneOtpState {
  final String message;
  CustomSmsVerifyPhoneOtpError(this.message);
}

const _userNotFoundCodes = ['USER_NOT_EXIST', 'otp_valid_but_user_not_found'];

// ── Cubit ────────────────────────────────────────────────────────────────────
class CustomSmsVerifyPhoneOtpCubit extends Cubit<CustomSmsVerifyPhoneOtpState>
    with ApiErrorGuard<CustomSmsVerifyPhoneOtpState> {
  final AuthRepository _repository;

  CustomSmsVerifyPhoneOtpCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(CustomSmsVerifyPhoneOtpInitial());

  Future<void> customSmsVerifyPhoneOtp({
    required String phoneNumber,
    required String otp,
    required String countryCode,
  }) async {
    emit(CustomSmsVerifyPhoneOtpLoading());
    try {
      final user = await _repository.customSmsVerifyPhoneOtp(
        phoneNumber: phoneNumber,
        otp: otp,
        countryCode: countryCode,
      );
      await AuthHiveBox.instance.saveLoginData(userLogin: user);
      emit(CustomSmsVerifyPhoneOtpLoaded(user));
    } on ApiException catch (e) {
      if (_userNotFoundCodes.contains(e.messageStatusCode)) {
        emit(CustomSmsVerifyPhoneOtpUserNotFound(phoneNumber));
      } else {
        emit(CustomSmsVerifyPhoneOtpError(e.message));
      }
    } catch (_) {
      emit(
        CustomSmsVerifyPhoneOtpError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(CustomSmsVerifyPhoneOtpInitial());
}
