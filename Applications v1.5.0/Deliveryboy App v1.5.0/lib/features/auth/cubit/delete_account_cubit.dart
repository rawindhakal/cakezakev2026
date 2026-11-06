import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';

typedef DeleteAccountState = AsyncState<()>;
typedef DeleteAccountInitial = AsyncInitial<()>;
typedef DeleteAccountLoading = AsyncLoading<()>;
typedef DeleteAccountLoaded = AsyncLoaded<()>;
typedef DeleteAccountError = AsyncError<()>;

/// Handles permanently deleting the authenticated delivery boy account.
class DeleteAccountCubit extends BaseAsyncCubit<()> {
  final AuthRepository _repository;

  DeleteAccountCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Deletes the account on the server and clears local auth data.
  Future<void> deleteAccount() => run(() async {
    await _repository.deleteAccount();
    await AuthHiveBox.instance.clearAuth();
    return ();
  });
}
