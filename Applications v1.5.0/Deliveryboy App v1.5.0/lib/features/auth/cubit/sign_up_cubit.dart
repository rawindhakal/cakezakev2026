import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../core/localization/services/localization_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../repositories/auth_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef SignUpState = AsyncState<String>;
typedef SignUpInitial = AsyncInitial<String>;
typedef SignUpLoading = AsyncLoading<String>;
typedef SignUpLoaded = AsyncLoaded<String>;
typedef SignUpError = AsyncError<String>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Handles delivery boy registration, including document uploads.
class SignUpCubit extends BaseAsyncCubit<String> {
  final AuthRepository _repository;

  SignUpCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Registers a new delivery boy account with the given details.
  Future<void> register({
    required String name,
    required String mobile,
    required String password,
    required String confirmPassword,
    required String bonusType,
    String? email,
    String? dob,
    String? profileImagePath,
    String? nationalIdImagePath,
    String? drivingLicenseImagePath,
    String? bonusPercentage,
    String? bonusMinAmount,
    String? bonusMaxAmount,
    String? returnBonusType,
    String? returnBonusPercentage,
    String? returnBonusMinAmount,
    String? returnBonusMaxAmount,
    String? countryId,
    String? countryCode,
    String? zoneId,
  }) => run(
    () async {
      final response = await _repository.register(
        name: name,
        mobile: mobile,
        password: password,
        confirmPassword: confirmPassword,
        email: email,
        dob: dob,
        profileImagePath: profileImagePath,
        nationalIdImagePath: nationalIdImagePath,
        drivingLicenseImagePath: drivingLicenseImagePath,
        bonusType: bonusType,
        bonusPercentage: bonusPercentage,
        bonusMinAmount: bonusMinAmount,
        bonusMaxAmount: bonusMaxAmount,
        returnBonusType: returnBonusType,
        returnBonusPercentage: returnBonusPercentage,
        returnBonusMinAmount: returnBonusMinAmount,
        returnBonusMaxAmount: returnBonusMaxAmount,
        countryId: countryId,
        countryCode: countryCode,
        zoneId: zoneId,
      );
      return response['message']?.toString() ??
          LocalizationService.instance.translate(
            LanguageLabelKeys.registrationSuccessful,
          );
    },
    onSuccess: (_) =>
        AnalyticsService.instance.logEvent(AppConstants.eventSignUp),
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'SignUp failed',
    ),
  );

  void reset() => emit(AsyncInitial());
}
