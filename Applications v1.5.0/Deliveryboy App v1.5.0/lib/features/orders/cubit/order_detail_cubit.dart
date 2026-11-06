import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../core/localization/services/localization_service.dart';
import '../models/order_detail_model.dart' hide Order;
import '../repositories/order_repository.dart';

typedef OrderDetailState = AsyncState<OrderDetailData>;
typedef OrderDetailInitial = AsyncInitial<OrderDetailData>;
typedef OrderDetailLoading = AsyncLoading<OrderDetailData>;
typedef OrderDetailLoaded = AsyncLoaded<OrderDetailData>;
typedef OrderDetailError = AsyncError<OrderDetailData>;

/// Loads a single quick order's full detail (order, items, timeline) by ID.
class OrderDetailCubit extends BaseAsyncCubit<OrderDetailData> {
  final OrderRepository _repository;

  OrderDetailCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the order detail for [orderId] and emits loading/loaded/error states.
  Future<void> loadOrder(String orderId) => run(() async {
    final result = await _repository.getOrderById(orderId);
    if (result.data == null) {
      throw ApiException(
        message: LocalizationService.instance.translate(
          LanguageLabelKeys.orderNotFound,
        ),
      );
    }
    return result.data!;
  });

  /// Emits already-fetched [data] straight away, without an API call — used
  /// when the detail was resolved elsewhere (e.g. the QR-scan lookup) and
  /// re-fetching it here would just be a redundant round trip.
  void loadFromData(OrderDetailData data) => emit(OrderDetailLoaded(data));
}
