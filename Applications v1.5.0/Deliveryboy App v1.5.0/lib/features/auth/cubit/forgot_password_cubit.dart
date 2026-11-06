import '../../../commons/cubit/base_async_cubit.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../core/localization/services/localization_service.dart';
import '../repositories/auth_repository.dart';

// ── States ────────────────────────────────────────────────────────────────────
typedef ForgotPasswordState = AsyncState<String>;
typedef ForgotPasswordInitial = AsyncInitial<String>;
typedef ForgotPasswordLoading = AsyncLoading<String>;
typedef ForgotPasswordLoaded = AsyncLoaded<String>;
typedef ForgotPasswordError = AsyncError<String>;

// ── Cubit ─────────────────────────────────────────────────────────────────────
/// Handles requesting a password reset OTP/link for a given email.
class ForgotPasswordCubit extends BaseAsyncCubit<String> {
  final AuthRepository _repository;

  ForgotPasswordCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Requests a password reset for the given email.
  Future<void> forgotPassword(String email) => run(() async {
    final response = await _repository.forgotPassword(email: email);
    return response['message']?.toString() ??
        LocalizationService.instance.translate(
          LanguageLabelKeys.otpSentSuccessfully,
        );
  });

  void reset() => emit(AsyncInitial());
}
