import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/orders/models/scan_delivery_receipt_model.dart';
import 'package:deliveryboy/features/orders/repositories/order_repository.dart';

typedef ScanDeliveryReceiptState = AsyncState<ScanDeliveryReceiptResponse>;
typedef ScanDeliveryReceiptInitial = AsyncInitial<ScanDeliveryReceiptResponse>;
typedef ScanDeliveryReceiptLoading = AsyncLoading<ScanDeliveryReceiptResponse>;
typedef ScanDeliveryReceiptLoaded = AsyncLoaded<ScanDeliveryReceiptResponse>;
typedef ScanDeliveryReceiptError = AsyncError<ScanDeliveryReceiptResponse>;

/// Resolves a scanned QR code to its order via /scan_delivery_receipt.
class ScanDeliveryReceiptCubit extends BaseAsyncCubit<ScanDeliveryReceiptResponse> {
  final OrderRepository _repository;

  ScanDeliveryReceiptCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository();

  Future<void> scan(String code) => run(() => _repository.scanDeliveryReceipt(code));
}
