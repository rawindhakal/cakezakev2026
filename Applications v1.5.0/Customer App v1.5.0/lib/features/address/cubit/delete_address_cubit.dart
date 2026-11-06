import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/address_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

sealed class DeleteAddressState {}

final class DeleteAddressInitial extends DeleteAddressState {}

final class DeleteAddressLoading extends DeleteAddressState {}

final class DeleteAddressSuccess extends DeleteAddressState {
  final String id;
  DeleteAddressSuccess(this.id);
}

final class DeleteAddressError extends DeleteAddressState {
  final String message;
  DeleteAddressError(this.message);
}

class DeleteAddressCubit extends Cubit<DeleteAddressState>
    with ApiErrorGuard<DeleteAddressState> {
  final AddressRepository _repository;

  DeleteAddressCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(DeleteAddressInitial());

  Future<void> deleteAddress({required String id}) async {
    emit(DeleteAddressLoading());
    await guard(() async {
      await _repository.deleteAddress(id: id);
      emit(DeleteAddressSuccess(id));
    }, onError: (msg) => emit(DeleteAddressError(msg)));
  }
}
