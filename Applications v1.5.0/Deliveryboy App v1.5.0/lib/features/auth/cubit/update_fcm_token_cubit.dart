import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';

typedef UpdateFcmTokenState = AsyncState<()>;
typedef UpdateFcmTokenInitial = AsyncInitial<()>;
typedef UpdateFcmTokenLoading = AsyncLoading<()>;
typedef UpdateFcmTokenLoaded = AsyncLoaded<()>;
typedef UpdateFcmTokenError = AsyncError<()>;

/// Updates the device's FCM token and active language on the server.
class UpdateFcmTokenCubit extends BaseAsyncCubit<()> {
  final AuthRepository _repository;

  UpdateFcmTokenCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Sends the updated FCM token, platform, and language to the server.
  Future<void> updateFcmToken({
    required String fcmToken,
    required String platform,
    required String languageId,
  }) => run(() async {
    await _repository.updateFcmToken(
      fcmToken: fcmToken,
      platform: platform,
      languageId: languageId,
    );
    return ();
  });
}
