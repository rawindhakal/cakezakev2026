import 'package:deliveryboy/commons/utils/app_haptics.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../cubit/scan_delivery_receipt_cubit.dart';
import '../models/ecommerce_order_model.dart';
import '../models/order_detail_model.dart' hide Order;

/// Scans a delivery-receipt QR code, resolves it via
/// [ScanDeliveryReceiptCubit], and opens the matching order's detail screen.
class OrderScannerScreen extends StatefulWidget {
  const OrderScannerScreen({super.key});

  @override
  State<OrderScannerScreen> createState() => _OrderScannerScreenState();
}

class _OrderScannerScreenState extends State<OrderScannerScreen> {
  static const _failedCodeCooldown = Duration(seconds: 3);

  final MobileScannerController _controller = MobileScannerController();

  // Guards against firing the API multiple times for the same frame burst
  // (mobile_scanner keeps detecting the same code every frame while it's in
  // view) and against the camera staying disabled forever if the scan turns
  // out to be a dead end — it's flipped back on for a fresh attempt.
  bool _handling = false;

  // Last code that resolved to an error/not-found, and when. A misread code
  // held in front of the camera gets redetected every frame — without this,
  // that reruns the API and re-shows the snackbar in a tight loop. Same code
  // within the cooldown is ignored; a different code, or the same one after
  // the cooldown, is retried normally.
  String? _lastFailedCode;
  DateTime? _lastFailedAt;
  String? _pendingCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    if (value == _lastFailedCode &&
        _lastFailedAt != null &&
        DateTime.now().difference(_lastFailedAt!) < _failedCodeCooldown) {
      return;
    }
    _handling = true;
    _pendingCode = value;
    AppHaptics.tap();
    await _controller.stop();
    if (!mounted) return;
    await context.read<ScanDeliveryReceiptCubit>().scan(value);
  }

  void _resumeScanning() {
    _handling = false;
    _controller.start();
  }

  void _markPendingCodeFailed() {
    _lastFailedCode = _pendingCode;
    _lastFailedAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScanDeliveryReceiptCubit, ScanDeliveryReceiptState>(
      listener: (context, state) {
        if (state is ScanDeliveryReceiptLoaded) {
          final response = state.data;
          final data = response.data;
          if (data == null) {
            AppSnackBar.show(
              context: context,
              message:
                  response.message ??
                  context.translate(LanguageLabelKeys.orderNotFoundForCode),
              type: SnackBarType.error,
            );
            _markPendingCodeFailed();
            _resumeScanning();
            return;
          }
          final returnRequestData = response.returnRequestData;
          if (returnRequestData != null) {
            AppNavigator.pushReplacementNamed(
              context,
              RouteNames.returnOrderDetail,
              arguments: returnRequestData,
            );
          } else if (response.isQuick) {
            AppNavigator.pushReplacementNamed(
              context,
              RouteNames.orderDetail,
              arguments: OrderDetailData.fromJson(data),
            );
          } else {
            AppNavigator.pushReplacementNamed(
              context,
              RouteNames.ecommerceOrderDetail,
              arguments: EcommerceOrderDataModel.fromJson(data),
            );
          }
        } else if (state is ScanDeliveryReceiptError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
          _markPendingCodeFailed();
          _resumeScanning();
        }
      },
      child: AppScaffold(
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.scanQrCode),
        ),
        applyBottomInset: false,
        body: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: MobileScanner(controller: _controller, onDetect: _onDetect),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.cs.primary, width: 3),
                    borderRadius: AppRadius.r16,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BlocBuilder<ScanDeliveryReceiptCubit, ScanDeliveryReceiptState>(
                builder: (context, state) {
                  if (state is! ScanDeliveryReceiptLoading) {
                    return const SizedBox.shrink();
                  }
                  return ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: ShimmerInline(size: 48, color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
