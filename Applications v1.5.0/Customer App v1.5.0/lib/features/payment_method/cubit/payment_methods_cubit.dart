import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:customer/features/payment_method/repositories/payment_repository.dart';

// ── States ───────────────────────────────────────────────────────────────────

sealed class PaymentMethodsState {}

final class PaymentMethodsInitial extends PaymentMethodsState {}

final class PaymentMethodsLoading extends PaymentMethodsState {}

final class PaymentMethodsLoaded extends PaymentMethodsState {
  PaymentMethodsLoaded({required this.data, required this.methods});

  final PaymentMethodsData data;
  final List<PaymentMethodItem> methods;
}

final class PaymentMethodsError extends PaymentMethodsState {
  PaymentMethodsError(this.message);

  final String message;
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class PaymentMethodsCubit extends Cubit<PaymentMethodsState>
    with ApiErrorGuard<PaymentMethodsState> {
  PaymentMethodsCubit({PaymentRepository? repository})
    : _repository = repository ?? PaymentRepository(),
      super(PaymentMethodsInitial());

  final PaymentRepository _repository;

  Future<void> loadPaymentMethods() async {
    emit(PaymentMethodsLoading());
    await guard(() async {
      final response = await _repository.getPaymentMethods();
      final methods = PaymentMethodItem.fromData(response.data);
      emit(PaymentMethodsLoaded(data: response.data, methods: methods));
    }, onError: (msg) => emit(PaymentMethodsError(msg)));
  }
}
