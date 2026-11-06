import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class DeleteAccountState {}

final class DeleteAccountInitial extends DeleteAccountState {}

final class DeleteAccountLoading extends DeleteAccountState {}

final class DeleteAccountLoaded extends DeleteAccountState {}

final class DeleteAccountError extends DeleteAccountState {
  final String message;
  DeleteAccountError(this.message);
}

class DeleteAccountCubit extends Cubit<DeleteAccountState>
    with ApiErrorGuard<DeleteAccountState> {
  final AuthRepository _repository;

  DeleteAccountCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(DeleteAccountInitial());

  Future<void> deleteAccount() async {
    emit(DeleteAccountLoading());
    await guard(() async {
      await _repository.deleteAccount();
      await AuthHiveBox.instance.clearAuth();
      emit(DeleteAccountLoaded());
    }, onError: (msg) => emit(DeleteAccountError(msg)));
  }
}
