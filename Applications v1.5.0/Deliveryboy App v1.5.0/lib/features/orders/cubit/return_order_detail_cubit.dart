import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../core/localization/services/localization_service.dart';
import '../models/return_order_model.dart';
import '../repositories/order_repository.dart';

typedef ReturnOrderDetailState = AsyncState<ReturnRequestData>;
typedef ReturnOrderDetailInitial = AsyncInitial<ReturnRequestData>;
typedef ReturnOrderDetailLoading = AsyncLoading<ReturnRequestData>;
typedef ReturnOrderDetailLoaded = AsyncLoaded<ReturnRequestData>;
typedef ReturnOrderDetailError = AsyncError<ReturnRequestData>;

/// Loads a single return request's full detail by its ID.
class ReturnOrderDetailCubit extends BaseAsyncCubit<ReturnRequestData> {
  final OrderRepository _repository;

  ReturnOrderDetailCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the return request detail for [returnRequestId].
  Future<void> loadDetail(String returnRequestId) => run(() async {
    final result = await _repository.getReturnRequestById(returnRequestId);
    if (result.data == null) {
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.returnRequestNotFound,
        ),
      );
    }
    return result.data!;
  });

  /// Emits [data] directly, skipping the API call — used when the caller
  /// already has the full detail (e.g. resolved locally via a QR scan).
  void loadLocal(ReturnRequestData data) => emit(AsyncLoaded<ReturnRequestData>(data));
}
