import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/order_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

sealed class InvoiceDownloadState {}

final class InvoiceDownloadInitial extends InvoiceDownloadState {}

final class InvoiceDownloadLoading extends InvoiceDownloadState {}

final class InvoiceDownloadLoaded extends InvoiceDownloadState {
  final File file;
  InvoiceDownloadLoaded(this.file);
}

final class InvoiceDownloadError extends InvoiceDownloadState {
  final String message;
  InvoiceDownloadError(this.message);
}

class InvoiceDownloadCubit extends Cubit<InvoiceDownloadState>
    with ApiErrorGuard<InvoiceDownloadState> {
  final OrderRepository _repository;

  InvoiceDownloadCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(InvoiceDownloadInitial());

  Future<void> downloadQuickInvoice(String orderId) async {
    emit(InvoiceDownloadLoading());
    await guard(() async {
      final file = await _repository.downloadQuickInvoice(orderId);
      emit(InvoiceDownloadLoaded(file));
    }, onError: (msg) => emit(InvoiceDownloadError(msg)));
  }

  Future<void> downloadEcommerceInvoice(String orderItemId) async {
    emit(InvoiceDownloadLoading());
    await guard(() async {
      final file = await _repository.downloadEcommerceInvoice(orderItemId);
      emit(InvoiceDownloadLoaded(file));
    }, onError: (msg) => emit(InvoiceDownloadError(msg)));
  }
}
