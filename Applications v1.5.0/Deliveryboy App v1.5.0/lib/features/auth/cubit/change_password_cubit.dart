import '../../../commons/cubit/base_async_cubit.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../core/localization/services/localization_service.dart';
import '../repositories/auth_repository.dart';

// ── States ────────────────────────────────────────────────────────────────────
typedef ChangePasswordState = AsyncState<String>;
typedef ChangePasswordInitial = AsyncInitial<String>;
typedef ChangePasswordLoading = AsyncLoading<String>;
typedef ChangePasswordLoaded = AsyncLoaded<String>;
typedef ChangePasswordError = AsyncError<String>;

// ── Cubit ─────────────────────────────────────────────────────────────────────
/// Handles changing the authenticated user's password.
class ChangePasswordCubit extends BaseAsyncCubit<String> {
  final AuthRepository _repository;

  ChangePasswordCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Submits the new password and confirmation to the server.
  Future<void> changePassword({
    required String oldPassword,
    required String password,
    required String confirmPassword,
  }) => run(() async {
    final response = await _repository.changePassword(
      oldPassword: oldPassword,
      password: password,
      confirmPassword: confirmPassword,
    );
    return response['message']?.toString() ??
        LocalizationService.instance.translate(
          LanguageLabelKeys.passwordChangedSuccessfully,
        );
  });

  void reset() => emit(AsyncInitial());
}
