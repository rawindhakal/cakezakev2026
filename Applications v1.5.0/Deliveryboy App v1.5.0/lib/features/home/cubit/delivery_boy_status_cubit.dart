import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';

typedef DeliveryBoyStatus = ({int status, String? remark});

typedef DeliveryBoyStatusState = AsyncState<DeliveryBoyStatus>;
typedef DeliveryBoyStatusInitial = AsyncInitial<DeliveryBoyStatus>;
typedef DeliveryBoyStatusLoading = AsyncLoading<DeliveryBoyStatus>;
typedef DeliveryBoyStatusLoaded = AsyncLoaded<DeliveryBoyStatus>;
typedef DeliveryBoyStatusError = AsyncError<DeliveryBoyStatus>;

/// Tracks and toggles the delivery boy's online/offline availability status.
class DeliveryBoyStatusCubit extends BaseAsyncCubit<DeliveryBoyStatus> {
  final AuthRepository _repository;

  DeliveryBoyStatusCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Fetches the current delivery boy status from the server.
  Future<void> checkStatus() => run(() async {
    final result = await _repository.getDeliveryBoyStatus();
    return (status: result.status, remark: result.remark);
  });

  /// Toggles between online/offline, persisting the change via the API
  /// (skipped when account is blocked). Rolls back on failure.
  Future<void> toggleOnline() async {
    final current = state;
    if (current is! DeliveryBoyStatusLoaded || current.data.status == 4) {
      return;
    }

    final newStatus = current.data.status == 1 ? 3 : 1;
    emit(AsyncLoaded((status: newStatus, remark: current.data.remark)));
    try {
      await _repository.updateDeliveryBoyStatus(status: newStatus);
    } on ApiException catch (e) {
      emit(AsyncError(e.message));
      emit(
        AsyncLoaded((status: current.data.status, remark: current.data.remark)),
      );
    } catch (_) {
      emit(
        AsyncLoaded((status: current.data.status, remark: current.data.remark)),
      );
    }
  }
}
