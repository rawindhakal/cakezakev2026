import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import '../models/ecommerce_order_model.dart';
import '../repositories/order_repository.dart';

typedef EcommerceOrderDetailState = AsyncState<EcommerceOrderDataModel>;
typedef EcommerceOrderDetailInitial = AsyncInitial<EcommerceOrderDataModel>;
typedef EcommerceOrderDetailLoading = AsyncLoading<EcommerceOrderDataModel>;
typedef EcommerceOrderDetailLoaded = AsyncLoaded<EcommerceOrderDataModel>;
typedef EcommerceOrderDetailError = AsyncError<EcommerceOrderDataModel>;

/// Loads a single ecommerce order item's full detail by its order-item ID.
class EcommerceOrderDetailCubit extends BaseAsyncCubit<EcommerceOrderDataModel> {
  final OrderRepository _repository;

  EcommerceOrderDetailCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  /// Fetches the ecommerce order detail for [orderItemId].
  Future<void> loadOrderDetail(String orderItemId) =>
      run(() => _repository.getEcommerceOrderDetail(orderItemId));

  /// Emits already-fetched [data] straight away, without an API call — used
  /// when the detail was resolved elsewhere (e.g. the QR-scan lookup) and
  /// re-fetching it here would just be a redundant round trip.
  void loadFromData(EcommerceOrderDataModel data) =>
      emit(EcommerceOrderDetailLoaded(data));
}
