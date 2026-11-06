import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../../../features/auth/models/auth_model.dart';
import '../../../features/auth/repositories/auth_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef ProfileUpdateState = AsyncState<AuthModel>;
typedef ProfileUpdateInitial = AsyncInitial<AuthModel>;
typedef ProfileUpdateLoading = AsyncLoading<AuthModel>;
typedef ProfileUpdateLoaded = AsyncLoaded<AuthModel>;
typedef ProfileUpdateError = AsyncError<AuthModel>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Manages updating the rider's profile details.
class ProfileUpdateCubit extends BaseAsyncCubit<AuthModel> {
  final AuthRepository _repository;

  ProfileUpdateCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Submits the updated profile fields to the server.
  Future<void> updateProfile({
    required String name,
    required String mobile,
    String? email,
    String? address,
    String? dob,
    String? bankAccountNumber,
    String? bankName,
    String? accountName,
    String? ifscCode,
    String? bonusType,
    String? bonusPercentage,
    String? bonusMinAmount,
    String? bonusMaxAmount,
    String? returnBonusType,
    String? returnBonusPercentage,
    String? returnBonusMinAmount,
    String? returnBonusMaxAmount,
    String? profileImagePath,
    String? nationalIdImagePath,
    String? drivingLicenseImagePath,
    String? countryId,
    String? zoneId,
  }) => run(
    () => _repository.updateProfile(
      name: name,
      mobile: mobile,
      email: email,
      address: address,
      dob: dob,
      bankAccountNumber: bankAccountNumber,
      bankName: bankName,
      accountName: accountName,
      ifscCode: ifscCode,
      bonusType: bonusType,
      bonusPercentage: bonusPercentage,
      bonusMinAmount: bonusMinAmount,
      bonusMaxAmount: bonusMaxAmount,
      returnBonusType: returnBonusType,
      returnBonusPercentage: returnBonusPercentage,
      returnBonusMinAmount: returnBonusMinAmount,
      returnBonusMaxAmount: returnBonusMaxAmount,
      profileImagePath: profileImagePath,
      nationalIdImagePath: nationalIdImagePath,
      drivingLicenseImagePath: drivingLicenseImagePath,
      countryId: countryId,
      zoneId: zoneId,
    ),
    onSuccess: (_) =>
        AnalyticsService.instance.logEvent(AppConstants.eventProfileUpdate),
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'updateProfile failed',
    ),
  );
}
