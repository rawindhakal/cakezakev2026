import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';

typedef LogoutState = AsyncState<()>;
typedef LogoutInitial = AsyncInitial<()>;
typedef LogoutLoading = AsyncLoading<()>;
typedef LogoutLoaded = AsyncLoaded<()>;
typedef LogoutError = AsyncError<()>;

/// Handles logging out the current delivery boy and clearing local session data.
class LogoutCubit extends BaseAsyncCubit<()> {
  final AuthRepository _repository;

  LogoutCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Logs out on the server and clears local auth data.
  Future<void> logout() => run(() async {
    await _repository.logout();
    await AuthHiveBox.instance.clearAuth();
    return ();
  });
}
