import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/local_storage/auth_hive_box.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/clarity_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../repositories/auth_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef SignInState = AsyncState<AuthModel>;
typedef SignInInitial = AsyncInitial<AuthModel>;
typedef SignInLoading = AsyncLoading<AuthModel>;
typedef SignInLoaded = AsyncLoaded<AuthModel>;
typedef SignInError = AsyncError<AuthModel>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Handles email/password login and post-login session/analytics setup.
class SignInCubit extends BaseAsyncCubit<AuthModel> {
  final AuthRepository _repository;

  SignInCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Logs in with email/password and persists the session on success.
  Future<void> login({
    required String email,
    required String password,
    String? fcmToken,
    String? platform,
    String? languageId,
  }) => run(
    () async {
      final user = await _repository.login(
        email: email,
        password: password,
        fcmToken: fcmToken,
        platform: platform,
        languageId: languageId,
      );
      await AuthHiveBox.instance.saveLoginData(auth: user);
      return user;
    },
    onSuccess: (user) {
      final userId = user.data?.id?.toString();
      AnalyticsService.instance.logEvent(
        AppConstants.eventLogin,
        parameters: {AppConstants.paramMethod: 'email_password'},
      );
      if (userId != null) {
        AnalyticsService.instance.setUserId(userId);
        CrashlyticsService.instance.setUserId(userId);
        ClarityService.setCustomTag(AppConstants.paramUserId, userId);
      }
    },
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'SignIn failed',
    ),
  );

  void reset() => emit(AsyncInitial());
}
