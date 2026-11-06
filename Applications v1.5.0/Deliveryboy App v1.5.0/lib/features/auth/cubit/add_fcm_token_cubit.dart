import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';

typedef AddFcmTokenState = AsyncState<()>;
typedef AddFcmTokenInitial = AsyncInitial<()>;
typedef AddFcmTokenLoading = AsyncLoading<()>;
typedef AddFcmTokenLoaded = AsyncLoaded<()>;
typedef AddFcmTokenError = AsyncError<()>;

/// Registers the device's FCM token with the server for push notifications.
class AddFcmTokenCubit extends BaseAsyncCubit<()> {
  final AuthRepository _repository;

  AddFcmTokenCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Sends the FCM token and platform to the server.
  Future<void> addFcmToken({
    required String fcmToken,
    required String platform,
  }) => run(() async {
    await _repository.addFcmToken(fcmToken: fcmToken, platform: platform);
    return ();
  });
}
